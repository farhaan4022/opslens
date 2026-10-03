output "ebs_csi_iam_role_arn" {
  description = "IAM role used by the EKS EBS CSI controller through IRSA"
  value       = aws_iam_role.ebs_csi.arn
}

output "ebs_csi_addon_version" {
  description = "Installed AWS EBS CSI EKS addon version"
  value       = aws_eks_addon.ebs_csi.addon_version
}
