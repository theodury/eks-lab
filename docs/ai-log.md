# AI usage log

| Date | What I asked Claude | What was wrong / missing | How I verified |
|------|---------------------|--------------------------|----------------|
| 2026-10-27 | Review the empty repo, write phase 0 and an easy on/off for the cluster | Docs assumed `terraform`; only OpenTofu is installed. AWS CLI and k6 missing. Pod density of t3.medium (17 pods) not considered in the plan | `tofu validate` on bootstrap, `make -n down` to read the teardown order, provider version checked on the registry |
| 2026-10-28 | Phase 1: write VPC + EKS with pinned versions | First `make plan` failed: macOS ships GNU Make 3.81, which does not pass exported vars (`AWS_PROFILE`) to `$(shell …)`, so the account ID was empty. Moved the lookup into the recipe | `make plan`: 53 to add, no KMS / log group / OIDC, add-on versions and `/32` endpoint checked in the plan |
