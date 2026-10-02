variable "aws_region" {
  description = "AWS region for OpsLens infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "opslens"
}

variable "allowed_ingress_cidr" {
  description = "CIDR allowed to access public OpsLens endpoints"
  type        = string
}

variable "ecs_desired_count" {
  description = "Number of Gotenberg ECS tasks"
  type        = number
  default     = 0
}

variable "eks_cluster_version" {
  description = "Kubernetes version used by the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type used by the EKS managed node group"
  type        = string
  default     = "m6i.large"
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 2
}
