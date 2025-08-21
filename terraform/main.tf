terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# ✅ Reference existing GitHub OIDC provider (don’t recreate)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "devops-portfolio-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:lthawkins48/devops-portfolio-hub:*"
          }
        }
      }
    ]
  })
}

# Attach ECR + EC2 permissions to the role
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "devops-portfolio-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ecr:*", "ecs:*", "ec2:*", "iam:PassRole"],
        Resource = "*"
      }
    ]
  })
}

# ECR repo for portfolio app
resource "aws_ecr_repository" "portfolio" {
  name = "devops-portfolio"
}

# Security group
resource "aws_security_group" "portfolio_sg" {
  name        = "portfolio-sg"
  description = "Allow HTTP access"
  vpc_id      = "vpc-0c3c4424e4cf7ed7d" # ⚠️ Replace with your default VPC ID

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "portfolio" {
  ami           = "ami-0866a3c8686eaeeba" # Ubuntu 22.04 in us-east-1
  instance_type = "t2.micro"
  security_groups = [aws_security_group.portfolio_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io git
              systemctl start docker
              systemctl enable docker

              # Run latest image from ECR
              aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.portfolio.repository_url}
              docker run -d -p 5000:5000 ${aws_ecr_repository.portfolio.repository_url}:latest
              EOF

  tags = {
    Name = "devops-portfolio-instance"
  }
}

output "portfolio_public_ip" {
  value = aws_instance.portfolio.public_ip
}

