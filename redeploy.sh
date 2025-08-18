#!/bin/bash
set -e

echo "==> Running destroy first (fresh redeploy)..."
./destroy.sh || true

cd terraform

echo "==> Initializing Terraform..."
terraform init -upgrade

echo "==> Applying Terraform..."
terraform apply -auto-approve

echo "==> Extracting SSH key..."
terraform output -raw portfolio_key_pem > devops-portfolio-key.pem
chmod 600 devops-portfolio-key.pem

IP=$(terraform output -raw portfolio_public_ip)
cd ..

echo "🌐 Instance public IP: $IP"
echo "⏳ Waiting for HTTP on $IP:5000..."

for i in {1..30}; do
  if curl -s "http://$IP:5000" >/dev/null; then
    echo "✅ App is live: http://$IP:5000"
    exit 0
  else
    echo "...waiting ($i/30)"
    sleep 10
  fi
done

echo "⚠️ App did not respond in time. Check later with:"
echo "   curl -v http://$IP:5000"

