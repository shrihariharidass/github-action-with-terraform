# main.tf
provider "aws" {
  region = "us-west-2"
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id           = aws_vpc.main.id
  cidr_block       = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "hello-world-app"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "hello-world-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "hello-world-app"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = 256
  memory                  = 512

  container_definitions = jsonencode([
    {
      name  = "hello-world"
      image = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
  }
}
