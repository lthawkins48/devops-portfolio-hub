#!/bin/bash
set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "Terraform not found. Install Terraform first." >&2
  exit 1
fi

echo "==> Redeploy: reading current IP from Terraform outputs..."
IP="$(terraform output -raw portfolio_public_ip 2>/dev/null || true)"

if [[ -z "${IP:-}" ]]; then
  echo "No IP yet. Running apply..."
  terraform init -upgrade -input=false
  terraform apply -auto-approve
  IP="$(terraform output -raw portfolio_public_ip)"
fi

echo "🌐 Instance public IP: $IP"
echo "⏳ Waiting for HTTP on $IP:5000..."

for i in {1..30}; do
  if curl -fsS "http://$IP:5000" >/dev/null; then
    echo "✅ App is live at: http://$IP:5000"
    exit 0
  fi
  echo "...waiting ($i/30)"
  sleep 5
done

echo "⚠️ App did not respond in time. Check with:"
echo "   curl -v http://$IP:5000"
exit 1

