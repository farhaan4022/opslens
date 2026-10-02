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
  description = "CIDR allowed to access the public ALB"
  type        = string
}

variable "ecs_desired_count" {
  description = "Number of Gotenberg ECS tasks"
  type        = number
  default     = 1
}
