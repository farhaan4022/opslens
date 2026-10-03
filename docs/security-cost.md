# Security and Cost Notes

## Security controls

### Network

- EKS workers run in private subnets.
- EKS API access is restricted.
- ALB ingress is restricted for the lab environment.
- Envoy admin is exposed only through a ClusterIP Service.
- Grafana is accessed through localhost port-forwarding instead of a public endpoint.

### Identity

Separate IAM roles are used for the EKS control plane and worker nodes.

IRSA is used for AWS-integrated controllers that need AWS API access:

- AWS Load Balancer Controller
- EBS CSI driver

The role trust relationships are scoped to the intended Kubernetes ServiceAccounts through the EKS OIDC provider.

### Kubernetes hardening

Envoy uses:

- `allowPrivilegeEscalation: false`
- default capability drop
- only the startup-required capabilities `CHOWN`, `SETGID`, and `SETUID`

The final gateway layer also uses:

- two replicas
- preferred pod anti-affinity
- `PodDisruptionBudget` with `minAvailable: 1`

### Storage

The durable-results S3 bucket has:

- public access blocked
- AES256 server-side encryption
- versioning enabled
- seven-day lifecycle expiration

Loki uses encrypted gp3 persistent storage through EBS CSI.

### Repository hygiene

Terraform state, plan files, private variable files, secrets, and local runtime artifacts are excluded from source control. GitHub Actions checks for prohibited tracked Terraform runtime files.

## Cost model

Primary live cost drivers in the lab are:

- EKS control plane
- EC2 worker nodes
- NAT Gateway
- Application Load Balancer
- EBS gp3 storage
- CloudWatch usage

The S3 validation workload is tiny and lifecycle-managed.

Two worker nodes were intentionally retained during observability, GitOps, and high-availability failure testing because node-level redundancy was required for those experiments.

The environment should be scaled down or destroyed when evidence collection is complete rather than left idle.

No exact long-term cost claim is made because AWS pricing and runtime duration vary.
