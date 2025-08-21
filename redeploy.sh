#!/bin/bash
set -e

echo "==> Redeploying portfolio app..."

cd terraform
terraform init -input=false
terraform apply -auto-approve

IP=$(terraform output -raw portfolio_public_ip)

echo "🌐 Instance public IP: $IP"
echo "⏳ Waiting for HTTP on $IP:5000..."

for i in {1..30}; do
  if curl -s "http://$IP:5000" > /dev/null; then
    echo "✅ App is live at: http://$IP:5000"
    exit 0
  fi
  echo "...waiting ($i/30)"
  sleep 5
done

echo "⚠️ App did not respond in time. Check with: curl -v http://$IP:5000"

