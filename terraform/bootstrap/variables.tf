variable "aws_region" {
  description = "AWS region for OpsLens infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID used for globally unique resources"
  type        = string
}
