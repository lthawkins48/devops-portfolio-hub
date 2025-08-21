output "portfolio_public_ip" {
  description = "Public IP of the portfolio instance"
  value       = aws_instance.portfolio.public_ip
}

