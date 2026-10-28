# Prompts à coller dans Claude Code (une phase à la fois)

## Démarrage (ce soir)
```
Lis CLAUDE.md et README.md. On commence la phase 0.
1) Vérifie mes prérequis (aws cli v2, terraform, kubectl, helm, k9s optionnel) et dis-moi ce qui manque.
2) Explique-moi en 5 lignes : AWS SSO/IAM Identity Center vs access keys, et pourquoi c'est du least privilege.
3) Crée infra/bootstrap (bucket S3 de state versionné + chiffré + bloqué en public, AWS Budget 20 USD avec alerte email).
4) Initialise docs/decisions.md et docs/ai-log.md.
Montre-moi le plan avant tout apply.
```

## Phase 1 — VPC + EKS
```
Phase 1. Avant de coder, fais-moi un tableau GKE -> EKS (VPC-native/VPC CNI, Workload Identity/Pod Identity,
node pools/managed node groups, authorized networks/endpoint public restreint, RBAC Google/access entries).
Puis écris infra/ avec les modules terraform-aws-modules vpc + eks (versions récentes vérifiées et pinées),
2 AZ, 1 NAT, node group Spot 2x t3.medium, endpoint public restreint à mon IP, access entry pour mon rôle SSO,
add-ons vpc-cni, coredns, kube-proxy, eks-pod-identity-agent. Backend S3 avec use_lockfile.
Montre-moi le plan et estime le coût horaire.
```

## Phase 2 — Exemple 1 : GitOps Argo CD
```
Phase 2. Explique Argo CD vs Flux CD (Application/ApplicationSet vs Kustomization/HelmRelease, sync waves,
self-heal, prune, UI). Installe Argo CD (Helm, version pinée), puis un app-of-apps qui pointe sur gitops/ de
mon repo GitHub. Première app : podinfo avec Kustomize (base + overlay "lab").
Ensuite fais-moi faire un exercice de drift : je change les replicas avec kubectl, on observe Argo le corriger.
```

## Phase 3 — Exemple 2 : L4 vs L7 + least privilege
```
Phase 3. Explique L4 (NLB, Service type LoadBalancer) vs L7 (ALB, Ingress, path routing, TLS, WAF possible),
et les security groups associés. Installe l'AWS Load Balancer Controller via Argo, avec un rôle IAM attaché par
EKS Pod Identity (policy officielle, pas d'admin). Expose podinfo une fois en ALB (Ingress) et une fois en NLB.
Montre-moi comment vérifier que le pod n'a QUE les droits prévus (aws sts get-caller-identity depuis un pod,
test d'un appel refusé).
```

## Phase 4 — Exemple 3 : Observabilité, SLO, pic de trafic
```
Phase 4. Installe kube-prometheus-stack en version légère via Argo (rétention courte, pas d'Alertmanager externe).
ServiceMonitor pour podinfo. Définis un SLO de disponibilité 99,5 % sur 30 j : recording rules SLI + alertes
burn-rate multi-fenêtres (1h/5m et 6h/30m). Ajoute un HPA sur podinfo, puis un test k6 qui simule un pic
(x10 en 1 min). Ensuite injecte des erreurs (podinfo a des endpoints /status/500) pour déclencher l'alerte.
Fais-moi résumer : capacité, headroom, ce que je mitigerais en premier en incident.
```

## Fin de session (à chaque fois)
```
Fais le teardown dans le bon ordre : supprime d'abord les apps Argo qui créent des LB, vérifie qu'il ne reste
aucun ALB/NLB, puis terraform destroy. Vérifie ensuite qu'il ne reste ni NAT, ni EIP, ni volume EBS.
Mets à jour docs/decisions.md et docs/ai-log.md, et fais-moi 5 questions d'entretien sur ce qu'on a fait.
```
