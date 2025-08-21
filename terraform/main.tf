provider "aws" {
  region = "us-east-1"
}

# ----------------------
# GitHub OIDC Provider
# ----------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "devops-portfolio-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:lthawkins48/devops-portfolio-hub:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "devops-portfolio-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:*",
          "ec2:*",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------
# ECR Repository
# ----------------------
resource "aws_ecr_repository" "portfolio" {
  name = "devops-portfolio"
}

# ----------------------
# Networking
# ----------------------
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "portfolio_sg" {
  name_prefix = "portfolio-sg-"
  description = "Allow inbound HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# ----------------------
# EC2 Instance
# ----------------------
resource "aws_instance" "portfolio" {
  ami           = "ami-08c40ec9ead489470" # Amazon Linux 2 in us-east-1
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.portfolio_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              $(aws ecr get-login --no-include-email --region us-east-1)
              docker pull ${aws_ecr_repository.portfolio.repository_url}:latest
              docker run -d -p 5000:5000 ${aws_ecr_repository.portfolio.repository_url}:latest
              EOF

  tags = {
    Name = "devops-portfolio-instance"
  }
}

