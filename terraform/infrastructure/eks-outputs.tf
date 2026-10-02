output "eks_cluster_name" {
  description = "Name of the OpsLens EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_version" {
  description = "Kubernetes version of the OpsLens EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_node_group_name" {
  description = "Name of the OpsLens EKS managed node group"
  value       = aws_eks_node_group.general.node_group_name
}
