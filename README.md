# EKS lab — GitOps, L4/L7 exposure, SLOs

A small, low-cost lab to get hands-on with **Amazon EKS**, **Argo CD** and **SLO-based alerting**,
coming from a GKE + Flux CD background. Built incrementally with Claude Code; decisions are in
`docs/decisions.md` and AI usage in `docs/ai-log.md`.

## Target architecture
```
Internet ──> ALB (L7, Ingress) ─┐
        └──> NLB (L4, Service) ─┤
                                ▼
 VPC 10.0.0.0/16, 2 AZs   public subnets: load balancers, NAT (x1)
                          private subnets: EKS managed node group (2x Spot)
 EKS (access entries, Pod Identity agent, VPC CNI)
   ├─ argocd            (app-of-apps from this repo)
   ├─ aws-lb-controller (IAM via EKS Pod Identity, least privilege)
   ├─ monitoring        (kube-prometheus-stack, light)
   └─ podinfo           (demo app, metrics, HPA)
```

## Phases
| # | Phase | What I learn | Done when |
|---|-------|--------------|-----------|
| 0 | Bootstrap ✅ | AWS SSO profile, S3 state + native lock, AWS Budget alert | `tofu init` works with remote state; budget alert at 20 USD |
| 1 | Network + EKS ✅ | VPC/subnets/NAT, EKS access entries, managed node group, add-ons | `kubectl get nodes` shows 2 Ready Spot nodes |
| 2 | **Example 1 — GitOps with Argo CD** ✅ | Argo CD vs Flux, app-of-apps, sync/self-heal, drift | podinfo deployed from Git; a manual `kubectl` change is reverted by Argo |
| 3 | **Example 2 — L4 vs L7 + least privilege** | AWS Load Balancer Controller, ALB Ingress vs NLB Service, security groups, Pod Identity, ExternalDNS on a delegated Route 53 zone | `pod.eks.technoga.net` served over HTTPS by an ALB and podinfo by an NLB; controller role scoped |
| 4 | **Example 3 — Capacity, SLO, surge** | Karpenter replaces the fixed node group; kube-prometheus-stack; Sloth-generated SLO rules and burn-rate alerts; HPA; k6 surge; a metric-cardinality drill | Karpenter adds a Spot node during the k6 surge; injected errors trigger a burn-rate alert; top cardinality offenders found and dropped by relabeling |
| 5 | Security baseline | Kyverno: non-root and read-only-rootfs policies, audit first, then enforce | A violating pod is reported in audit, refused in enforce; podinfo still runs |
| 6 | Plan-on-PR | GitHub Actions runs `tofu plan` on every PR, AWS auth by OIDC, no stored key | A PR shows its plan as a comment; apply stays on the laptop by Theo |
| 7 | Incident drill | Kill a node during the surge, mitigate, then write a blameless postmortem in `docs/` | Postmortem with timeline, root cause, detection gaps and owned action items |
| 8 | Teardown | Safe destroy order | Nothing left in the account (check LBs, NAT, EIPs, EBS) |

Optional, time permitting: KEDA with a cron scaler (scale up before a scheduled peak), an ApplicationSet that stamps `uat` and `prod` namespaces to rehearse promotion by PR, a Terraform drift drill.

## Cost (rough, eu-west-1 — verify with the AWS pricing pages)
EKS control plane ~0.10 USD/h · NAT gateway ~0.05 USD/h + data · 2 Spot t3.medium ~0.03 USD/h ·
ALB/NLB ~0.025 USD/h each · public IPv4 ~0.005 USD/h each → **≈ 0.25 USD/h, ~1 USD per evening. Destroy after each session.**
Always on: the state bucket and the `eks.technoga.net` Route 53 zone, ~0.50 USD/month.

## Usage
```bash
make login                                   # aws sso login, profile eks-lab
echo 'budget_email = "me@example.com"' > infra/bootstrap/terraform.tfvars   # gitignored
make bootstrap                               # once: state bucket, budget, Route 53 zone
make up        # create VPC + EKS (~15 min), write kubeconfig context "eks-lab", install Argo CD + root app
make argocd    # (re)install Argo CD and the root app on a running cluster
make down      # delete LB-creating objects, then tofu destroy
make status    # anything still billing? (clusters, LBs, NAT, EIPs, loose EBS) — should be empty
```
