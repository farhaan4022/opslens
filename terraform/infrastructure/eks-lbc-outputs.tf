output "aws_load_balancer_controller_role_arn" {
  description = "IAM role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}
