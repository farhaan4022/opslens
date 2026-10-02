resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Project = var.project_name
  }
}

data "aws_ecr_image" "gotenberg" {
  repository_name = aws_ecr_repository.gotenberg.name
  image_tag       = "8.37.0"
}

resource "aws_ecs_task_definition" "gotenberg" {
  family                   = "${var.project_name}-gotenberg"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "1024"
  memory = "2048"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name = "gotenberg"

      image = "${aws_ecr_repository.gotenberg.repository_url}@${data.aws_ecr_image.gotenberg.image_digest}"

      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.gotenberg.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Project = var.project_name
  }
}

resource "aws_ecs_service" "gotenberg" {
  name            = "${var.project_name}-gotenberg"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gotenberg.arn

  desired_count = 1
  launch_type   = "FARGATE"

  health_check_grace_period_seconds = 30

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gotenberg.arn
    container_name   = "gotenberg"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = {
    Project = var.project_name
  }
}
