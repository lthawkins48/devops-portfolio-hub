terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Generate a fresh SSH keypair every run
resource "tls_private_key" "portfolio_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "portfolio" {
  key_name   = "devops-portfolio-key-${timestamp()}"
  public_key = tls_private_key.portfolio_key.public_key_openssh
}

resource "aws_security_group" "portfolio_sg" {
  name        = "portfolio-sg-${timestamp()}"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask App"
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

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "portfolio" {
  ami                         = "ami-08c40ec9ead489470" # Ubuntu 22.04 in us-east-1
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.portfolio.key_name
  vpc_security_group_ids      = [aws_security_group.portfolio_sg.id]

  tags = {
    Name = "devops-portfolio-instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              docker run -d -p 5000:5000 lthawkins48/devops-portfolio:latest
              EOF
}

output "portfolio_public_ip" {
  value = aws_instance.portfolio.public_ip
}

output "portfolio_key_pem" {
  value     = tls_private_key.portfolio_key.private_key_pem
  sensitive = true
}

