provider "aws" {
  region = var.AWS_REGION
  assume_role {
    role_arn = "arn:aws:iam::${var.AWS_ACCOUNT_ID}:role/CdkDeployer"
  }
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "webapp-tf"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "webapp_tf_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "webapp-tf-vpc"
  }
}

resource "aws_internet_gateway" "webapp_tf_igw" {
  vpc_id = aws_vpc.webapp_tf_vpc.id

  tags = {
    Name = "webapp-tf-igw"
  }
}

resource "aws_subnet" "webapp_tf_public_subnet_c" {
  vpc_id                  = aws_vpc.webapp_tf_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.AWS_REGION}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "webapp-tf-public-subnet-c"
  }
}

resource "aws_subnet" "webapp_tf_public_subnet_b" {
  vpc_id                  = aws_vpc.webapp_tf_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.AWS_REGION}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "webapp-tf-public-subnet-b"
  }
}

resource "aws_route_table" "webapp_tf_public_rt" {
  vpc_id = aws_vpc.webapp_tf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webapp_tf_igw.id
  }

  tags = {
    Name = "webapp-tf-public-rt"
  }
}

resource "aws_route_table_association" "webapp_tf_public_subnet_c_assoc" {
  subnet_id      = aws_subnet.webapp_tf_public_subnet_c.id
  route_table_id = aws_route_table.webapp_tf_public_rt.id
}

resource "aws_route_table_association" "webapp_tf_public_subnet_b_assoc" {
  subnet_id      = aws_subnet.webapp_tf_public_subnet_b.id
  route_table_id = aws_route_table.webapp_tf_public_rt.id
}

resource "aws_security_group" "webapp_tf_alb_sg" {
  name        = "webapp-tf-alb-sg"
  description = "Security group for webapp-tf ALB"
  vpc_id      = aws_vpc.webapp_tf_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp-tf-alb-sg"
  }
}

resource "aws_security_group" "webapp_tf_ecs_service_sg" {
  name        = "webapp-tf-ecs-service-sg"
  description = "Security group for webapp-tf ECS service"
  vpc_id      = aws_vpc.webapp_tf_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.webapp_tf_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp-tf-ecs-service-sg"
  }
}

resource "aws_lb" "webapp_tf_alb" {
  name               = "webapp-tf-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webapp_tf_alb_sg.id]
  subnets            = [aws_subnet.webapp_tf_public_subnet_c.id, aws_subnet.webapp_tf_public_subnet_b.id]

  tags = {
    Name = "webapp-tf-alb"
  }
}

resource "aws_lb_target_group" "webapp_tf_tg" {
  name        = "webapp-tf-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.webapp_tf_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "webapp-tf-tg"
  }
}

resource "aws_lb_listener" "webapp_tf_listener" {
  load_balancer_arn = aws_lb.webapp_tf_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_tf_tg.arn
  }
}

resource "aws_ecs_cluster" "webapp_tf_cluster" {
  name = "webapp-tf-cluster"

  tags = {
    Name = "webapp-tf-cluster"
  }
}

resource "aws_ecs_task_definition" "webapp_tf_task" {
  family                   = "webapp-tf-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "webapp-tf-container"
      image     = "ghcr.io/${var.GITHUB_REPOSITORY_OWNER}/${var.CONTAINER_IMAGE_NAME}:${var.CONTAINER_IMAGE_TAG}"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])

  tags = {
    Name = "webapp-tf-task"
  }
}

resource "aws_ecs_service" "webapp_tf_service" {
  name            = "webapp-tf-service"
  cluster         = aws_ecs_cluster.webapp_tf_cluster.id
  task_definition = aws_ecs_task_definition.webapp_tf_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.webapp_tf_public_subnet_c.id, aws_subnet.webapp_tf_public_subnet_b.id]
    security_groups = [aws_security_group.webapp_tf_ecs_service_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webapp_tf_tg.arn
    container_name   = "webapp-tf-container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.webapp_tf_listener]

  tags = {
    Name = "webapp-tf-service"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "webapp-tf-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "webapp-tf-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "webapp-tf-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name = "webapp-tf-ecs-task-role"
  }
}
