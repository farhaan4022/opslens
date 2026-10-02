# Experiment 009 - ECS Single-Task Cloud Baseline

## Objective

Establish the first AWS cloud baseline for Gotenberg before testing horizontal
scaling or autoscaling.

## Runtime

- AWS region: ap-south-1
- ECS launch type: Fargate
- ECS desired tasks: 1
- Task CPU: 1024 CPU units / 1 vCPU
- Task memory: 2048 MiB
- Gotenberg version: 8.37.0
- Container image: private Amazon ECR image pinned by digest
- Container port: 3000
- Tasks run in private subnets
- Public ingress is provided through an Application Load Balancer
- ALB listener: HTTP port 80
- Target group health check: /health
- CloudWatch logging enabled
- ECS Container Insights enabled

## Purpose

This experiment establishes a cloud single-task baseline before testing
multiple ECS tasks. Results should not be interpreted as a direct latency
comparison with localhost because requests now include internet and ALB network
latency.
