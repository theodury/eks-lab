export AWS_PROFILE ?= eks-lab
export AWS_REGION  ?= eu-west-1
CLUSTER := eks-lab
TF      := tofu -chdir=infra
MY_IP    = $(shell curl -s https://checkip.amazonaws.com)
KC      := kubectl --context $(CLUSTER)

.PHONY: login bootstrap init plan up down status

login:
	aws sso login

bootstrap:
	tofu -chdir=infra/bootstrap init
	tofu -chdir=infra/bootstrap apply

init:
	$(TF) init -reconfigure -backend-config=bucket=eks-lab-tfstate-$$(aws sts get-caller-identity --query Account --output text)

plan: init
	$(TF) plan -var my_ip=$(MY_IP)

up: init
	$(TF) apply -var my_ip=$(MY_IP)
	prev=$$(kubectl config current-context 2>/dev/null); \
	aws eks update-kubeconfig --name $(CLUSTER) --alias $(CLUSTER); \
	[ -z "$$prev" ] || kubectl config use-context "$$prev"

# ALBs/NLBs are created by the LB controller, not by tofu: they must be gone
# before destroy or the VPC deletion hangs. Argo's controller is stopped first,
# otherwise self-heal recreates the Ingress/Services we delete.
down: init
	@if $(KC) get ns >/dev/null 2>&1; then \
	  $(KC) -n argocd scale statefulset argocd-application-controller --replicas=0 2>/dev/null; \
	  $(KC) delete ingress --all --all-namespaces --wait; \
	  $(KC) get svc --all-namespaces -o json \
	    | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' \
	    | while read ns name; do $(KC) -n $$ns delete svc $$name --wait; done; \
	fi
	$(TF) destroy -var my_ip=$(MY_IP)

status:
	@echo "EKS clusters:  $$(aws eks list-clusters --query clusters --output text)"
	@echo "Load balancers: $$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text)"
	@echo "NAT gateways:  $$(aws ec2 describe-nat-gateways --filter Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId' --output text)"
	@echo "Elastic IPs:   $$(aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text)"
	@echo "Loose EBS:     $$(aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text)"
