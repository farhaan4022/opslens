# OpsLens Terraform Infrastructure

This directory contains Infrastructure as Code (IaC) used to provision and manage AWS resources for the OpsLens platform.

Terraform is used to create reproducible cloud infrastructure instead of manually creating resources through the AWS console.

---

## Directory Structure

terraform/
├── bootstrap/
│
│   Creates Terraform backend resources:
│   - S3 bucket for remote state storage
│   - DynamoDB table for state locking
│
└── infrastructure/
Creates application infrastructure:
- VPC networking
- Security groups
- IAM roles
- ECS services
- Application Load Balancer
- Monitoring resources

---

## Authentication

AWS credentials are not stored inside this repository.

Terraform authentication uses an AWS CLI profile configured locally:

opslens

This prevents sensitive credentials from being committed to source control.

---

## Terraform State Management

Terraform state is stored remotely using AWS services.

Remote state:

Amazon S3

State locking:

Amazon DynamoDB

Benefits:

- prevents concurrent Terraform modifications
- keeps infrastructure state outside developer machines
- supports future CI/CD integration

---

## Deployment Approach

Infrastructure changes follow this workflow:

terraform init
terraform plan
terraform apply

All AWS resources are created and managed through Terraform code.
