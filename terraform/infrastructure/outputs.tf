output "vpc_id" {
  description = "ID of the OpsLens VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"

  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"

  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Gotenberg image"
  value       = aws_ecr_repository.gotenberg.repository_url
}

output "ecs_cluster_name" {
  description = "OpsLens ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "Legacy ECS ALB DNS name when enabled"
  value       = var.ecs_alb_enabled ? aws_lb.main[0].dns_name : null
}

output "gotenberg_image_digest" {
  description = "ECR image digest used by the Gotenberg workload"
  value       = data.aws_ecr_image.gotenberg.image_digest
}
