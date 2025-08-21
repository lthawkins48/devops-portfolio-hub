#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating folders"
mkdir -p app/templates app/static docs .github/workflows

echo "==> Writing .gitignore"
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.pyc

# Docker
*.log
.env

# Terraform
.terraform/
*.tfstate
*.tfstate.backup
crash.log

# Keys / creds
*.pem
*.key
.ssh/
EOF

echo "==> Writing Flask app"
cat > app/main.py << 'EOF'
from flask import Flask, render_template, send_from_directory

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/devs-opsy")
def devs_opsy():
    return render_template("devs-opsy.html")

@app.route("/static/docs/<path:filename>")
def docs_static(filename):
    return send_from_directory("static/docs", filename)

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
EOF

echo "==> Writing templates"
cat > app/templates/index.html << 'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>DevOps Portfolio</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <h1>Welcome to DevOps Portfolio</h1>
  <p><a href="/devs-opsy">DevOpsy diagram & links</a></p>
</body>
</html>
EOF

cat > app/templates/devs-opsy.html << 'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>DevOpsy</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <h1>DevOpsy</h1>
  <p>Below is the deployment diagram embedded from <code>docs/diagram1.svg</code>.</p>
  <img src="/static/docs/diagram1.svg" alt="Deployment Diagram" style="max-width: 900px; width: 100%;">
  <h2>Project Links</h2>
  <ul>
    <li><a target="_blank" href="https://github.com/lthawkins48/devops-portfolio-hub">GitHub Repository</a></li>
    <li><a target="_blank" href="https://hub.docker.com/r/lthawkins48/devops-portfolio">Docker Hub Image</a></li>
  </ul>
</body>
</html>
EOF

echo "==> Writing CSS"
cat > app/static/style.css << 'EOF'
body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell; margin: 40px; line-height: 1.5; }
h1, h2 { margin-bottom: 0.4rem; }
a { text-decoration: none; }
EOF

echo "==> Writing placeholder diagram (SVG)"
mkdir -p app/static/docs
cat > app/static/docs/diagram1.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="760" height="380">
  <rect x="10" y="10" width="220" height="120" fill="#eef" stroke="#88f"/>
  <text x="30" y="40" font-size="16">GitHub Actions (OIDC)</text>
  <text x="30" y="65" font-size="14">build & push Docker</text>
  <text x="30" y="85" font-size="14">assume AWS role</text>

  <rect x="270" y="10" width="220" height="120" fill="#efe" stroke="#8f8"/>
  <text x="290" y="40" font-size="16">AWS SSM</text>
  <text x="290" y="65" font-size="14">SendCommand</text>

  <rect x="530" y="10" width="220" height="120" fill="#fee" stroke="#f88"/>
  <text x="550" y="40" font-size="16">EC2 (AL2023)</text>
  <text x="550" y="65" font-size="14">Docker run :5000</text>

  <line x1="230" y1="70" x2="270" y2="70" stroke="#333" marker-end="url(#a)"/>
  <line x1="490" y1="70" x2="530" y2="70" stroke="#333" marker-end="url(#a)"/>

  <defs>
    <marker id="a" markerWidth="10" markerHeight="10" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L9,3 z" fill="#333" />
    </marker>
  </defs>
</svg>
EOF

echo "==> Writing Dockerfile"
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
ENV PYTHONUNBUFFERED=1
EXPOSE 5000
CMD ["python", "app/main.py"]
EOF

echo "==> Writing requirements.txt"
cat > requirements.txt << 'EOF'
flask==3.0.3
gunicorn==22.0.0
EOF

echo "==> Writing GitHub Actions workflow"
cat > .github/workflows/deploy.yml << 'EOF'
name: CI/CD - Build & Deploy (OIDC + SSM)

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  DOCKER_IMAGE: docker.io/lthawkins48/devops-portfolio

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ env.DOCKER_IMAGE }}:latest,${{ env.DOCKER_IMAGE }}:${{ github.sha }}

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get Instance IDs by tag
        id: instances
        run: |
          IDS=$(aws ec2 describe-instances \
            --filters "Name=tag:Project,Values=DevOpsPortfolio" "Name=instance-state-name,Values=running" \
            --query "Reservations[].Instances[].InstanceId" --output text)
          if [ -z "$IDS" ]; then echo "No running instances found"; exit 1; fi
          echo "ids=$IDS" >> $GITHUB_OUTPUT

      - name: Trigger SSM rolling restart
        run: |
          read -r -a ARR <<< "${{ steps.instances.outputs.ids }}"
          for IID in "${ARR[@]}"; do
            CMD_ID=$(aws ssm send-command \
              --document-name "AWS-RunShellScript" \
              --instance-ids "$IID" \
              --parameters commands='[
                "set -euxo pipefail",
                "CONTAINER=devops-portfolio",
                "IMAGE=docker.io/lthawkins48/devops-portfolio:latest",
                "docker rm -f $CONTAINER || true",
                "docker pull $IMAGE",
                "docker run -d --restart=always --name $CONTAINER -p 5000:5000 -e PORT=5000 $IMAGE"
              ]' \
              --query "Command.CommandId" --output text)
            echo "Sent command $CMD_ID to $IID"
            # poll until Success/Failed
            for i in $(seq 1 30); do
              STATUS=$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$IID" --query "Status" --output text || true)
              echo "[$i] $IID status: $STATUS"
              if [ "$STATUS" = "Success" ]; then break; fi
              if [[ "$STATUS" =~ Failed|Cancelled|TimedOut ]]; then echo "❌ SSM failed"; exit 1; fi
              sleep 5
            done
          done

      - name: Health check
        run: |
          IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Project,Values=DevOpsPortfolio" "Name=instance-state-name,Values=running" \
            --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
          echo "Public IP: $IP"
          for i in $(seq 1 30); do
            if curl -fsS "http://$IP:5000/" >/dev/null; then
              echo "✅ App healthy at http://$IP:5000"
              exit 0
            fi
            echo "waiting ($i/30)..."
            sleep 5
          done
          echo "App did not become healthy"; exit 1
EOF

echo "==> Done. Next: commit & push after Terraform."

