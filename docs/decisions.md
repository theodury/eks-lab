# Decisions (ADR-lite)

## ADR-001 — OpenTofu instead of Terraform
- **Context**: the target team uses Terraform. Only OpenTofu 1.13 is installed on my machine.
- **Options**: install Terraform; use OpenTofu.
- **Decision**: OpenTofu. Same HCL, same providers, same `terraform-aws-modules`, S3 native locking (`use_lockfile`) since 1.10.
- **Trade-off / what I'd do in production**: follow the team's tool. Everything here transfers to Terraform 1.10+ as is, except the CLI name.

## ADR-002 — "Off" means destroy, not scale to zero
- **Context**: I want to switch the lab on and off cheaply between evenings.
- **Options**: scale the node group to 0; destroy everything except the state bucket.
- **Decision**: two layers. `infra/bootstrap/` (S3 state bucket + budget, ~0 USD) stays forever.
  `infra/` (VPC, NAT, EKS, nodes) is created by `make up` and destroyed by `make down`.
  Argo CD rebuilds the workloads from Git after each `up`.
- **Trade-off / what I'd do in production**: scaling nodes to 0 still bills the EKS control plane and the NAT
  (~0.15 USD/h, ~105 USD/month). Destroy costs ~15 min per `up`, and turns every evening into a rebuild-from-Git drill.
  In production you never destroy, you scale with Karpenter or cluster-autoscaler.

## ADR-003 — State bucket name and backend config kept out of Git
- **Context**: S3 bucket names are global; the repo is public.
- **Decision**: bucket named `eks-lab-tfstate-<account-id>`, computed from `aws_caller_identity`. `infra/` gets it through
  `-backend-config` from the Makefile, so neither the account ID nor an email lands in Git.
  The bootstrap layer keeps a local, gitignored state: it is the chicken-and-egg layer, and can be re-imported if lost.
- **Trade-off / what I'd do in production**: bootstrap state also lives remotely, created once by a platform team or account vending.

## ADR-004 — EKS cluster shape (phase 1)
- **Context**: cheapest cluster that still shows the production-relevant EKS features.
- **Decisions**:
  - Kubernetes **1.37**, the newest version in EKS standard support (until 2027-12). Modules pinned: `vpc` 6.7.3, `eks` 21.29.0.
    Add-ons pinned to the AWS *default* version for 1.37, not the newest build: the default is the one AWS validated.
  - **Access entries only** (`authentication_mode = "API"`), no `aws-auth` ConfigMap. My SSO role gets `AmazonEKSClusterAdminPolicy`.
  - **No IRSA OIDC provider**: workloads will use EKS Pod Identity.
  - **No customer KMS key, no control-plane logs**: EKS already encrypts Secrets with an AWS-owned key, and a per-`up`
    KMS key or log group would survive each destroy (KMS has a 7–30 day deletion window).
  - **VPC CNI prefix delegation**: a t3.medium holds 17 pods with one IP per pod, ~110 with /28 prefixes. Private subnets are /19 so prefixes fit.
  - Public API endpoint restricted to my current IP (`/32`), refreshed by the Makefile at each run.
  - Node group: 2x Spot, two instance types (t3.medium, t3a.medium) to widen the Spot pool.
- **Trade-off / what I'd do in production**: control-plane audit logs on, customer KMS key if compliance asks,
  a NAT per AZ, private endpoint behind VPN/SSM, VPC CNI credentials via Pod Identity instead of the node role,
  Karpenter instead of a fixed node group.
