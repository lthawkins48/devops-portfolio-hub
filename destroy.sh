#!/bin/bash
set -e

cd terraform

echo "==> Destroying Terraform-managed resources..."
terraform destroy -auto-approve || true

echo "==> Cleaning Terraform state and keys..."
rm -f terraform.tfstate terraform.tfstate.backup devops-portfolio-key.pem
rm -rf .terraform .terraform.lock.hcl

cd ..

echo "✅ Environment destroyed and cleaned."

