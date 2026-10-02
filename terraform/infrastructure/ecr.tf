resource "aws_ecr_repository" "gotenberg" {
  name                 = "${var.project_name}/gotenberg"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "gotenberg" {
  repository = aws_ecr_repository.gotenberg.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the five most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
