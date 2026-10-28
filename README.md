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
| 0 | Bootstrap | AWS SSO profile, S3 state + native lock, AWS Budget alert | `terraform init` works with remote state; budget alert at 20 USD |
| 1 | Network + EKS | VPC/subnets/NAT, EKS access entries, managed node group, add-ons | `kubectl get nodes` shows 2 Ready Spot nodes |
| 2 | **Example 1 — GitOps with Argo CD** | Argo CD vs Flux, app-of-apps, sync/self-heal, drift | podinfo deployed from Git; a manual `kubectl` change is reverted by Argo |
| 3 | **Example 2 — L4 vs L7 + least privilege** | AWS Load Balancer Controller, ALB Ingress vs NLB Service, security groups, Pod Identity | podinfo reachable via ALB (path routing, health checks) and NLB; controller role scoped |
| 4 | **Example 3 — Observability, SLO, surge** | ServiceMonitor, SLI/SLO, multi-window burn-rate alerts, HPA, load test | Grafana shows SLI; a k6 surge triggers HPA scale-out and (with injected errors) a burn-rate alert |
| 5 | Teardown | Safe destroy order | Nothing left in the account (check LBs, NAT, EIPs, EBS) |

Optional bonus: Terraform drift drill (change a tag in the console → `terraform plan` shows drift → decide: import or revert).

## Cost (rough, eu-west-1 — verify with the AWS pricing pages)
EKS control plane ~0.10 USD/h · NAT gateway ~0.05 USD/h + data · 2 Spot t3.medium ~0.03 USD/h ·
ALB/NLB ~0.025 USD/h each → **≈ 0.25 USD/h, ~1 USD per evening. Destroy after each session.**

## Usage
```bash
make login                                   # aws sso login, profile eks-lab
TF_VAR_budget_email=me@example.com make bootstrap   # once: state bucket + budget
make up        # create VPC + EKS (~15 min), write kubeconfig context "eks-lab"
make down      # delete LB-creating objects, then tofu destroy
make status    # anything still billing? (clusters, LBs, NAT, EIPs, loose EBS) — should be empty
```
