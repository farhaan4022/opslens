output "vpc_id" {
  description = "ID of the OpsLens VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the load balancer"

  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS workloads"

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
  description = "Public DNS name of the OpsLens application load balancer"
  value       = aws_lb.main.dns_name
}

output "gotenberg_image_digest" {
  description = "ECR image digest used by the ECS task definition"
  value       = data.aws_ecr_image.gotenberg.image_digest
}
