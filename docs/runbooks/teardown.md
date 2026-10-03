# OpsLens Teardown Runbook

## Purpose

OpsLens contains billable AWS resources. Teardown should preserve evidence while respecting resource ownership.

## 1. Preserve repository evidence

```bash
git status
git push origin main
```

Confirm required experiment logs and documentation are committed. Never add private Terraform variables, state, credentials, or secrets to Git.

## 2. Review Kubernetes resources

```bash
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
kubectl get applications -n argocd
```

## 3. Respect ownership

AWS infrastructure is Terraform-owned. Do not manually delete Terraform-managed VPC, NAT, EKS, node-group, IAM, S3, or related resources unless intentionally recovering from an exceptional state.

## 4. Review Terraform destroy plan

```bash
terraform -chdir=terraform/infrastructure plan -destroy
```

Inspect the full plan before execution.

## 5. Destroy workload infrastructure

Only after reviewing the plan:

```bash
terraform -chdir=terraform/infrastructure destroy
```

Use the same required private variable inputs that were used to create the environment.

## 6. Preserve Terraform bootstrap until last

The Terraform state bucket and lock resources are separate bootstrap infrastructure. Do not destroy them before all workload infrastructure has been removed and the state is no longer needed.

## 7. Final AWS review

Check for remaining project resources, especially:

- EKS clusters
- EC2 instances
- NAT Gateways
- load balancers
- EBS volumes
- Elastic IP addresses
- S3 buckets
- CloudWatch log groups

The objective is to avoid leaving idle billable infrastructure after the lab is complete.
