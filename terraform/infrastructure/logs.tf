resource "aws_cloudwatch_log_group" "gotenberg" {
  name              = "/ecs/${var.project_name}/gotenberg"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}
