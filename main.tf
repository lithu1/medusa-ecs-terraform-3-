provider "aws" {
  region = var.aws_region
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Use the default subnet IDs from the default VPC
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Create a Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  description = "Allow all inbound and outbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "medusa-cluster"
}

# Use the existing execution role created by AWS (no IAM conflict)
data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
}

# ECS Task Definition for Medusa
resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "medusa",
      image = "medusajs/medusa:v1.13.1",
      portMappings = [
        {
          containerPort = 9000
        }
      ],
      environment = [
        {
          name  = "DATABASE_URL",
          value = "sqlite://./medusa-db.sqlite"
        }
      ]
    }
  ])
}

# ECS Fargate Service
resource "aws_ecs_service" "service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [tolist(data.aws_subnet_ids.default.ids)[0]]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}

# Output ECS Cluster name
output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
