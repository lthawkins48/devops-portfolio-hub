#!/bin/bash
set -e

echo "==> Destroying portfolio infrastructure..."

cd terraform
terraform destroy -auto-approve

echo "✅ Infrastructure destroyed."

