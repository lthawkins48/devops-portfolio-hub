#!/bin/bash
set -e

echo "==> Creating project folders..."
mkdir -p terraform app

echo "==> Writing .gitignore..."
cat > .gitignore <<EOL
terraform/.terraform/
terraform/terraform.tfstate*
terraform/*.pem
__pycache__/
*.pyc
*.log
*.env
EOL

echo "==> Writing sample Flask app..."
cat > app/main.py <<EOL
from flask import Flask
app = Flask(__name__)

@app.route("/")
def home():
    return "🚀 DevOps Portfolio Hub is running!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOL

echo "==> Writing requirements.txt..."
cat > app/requirements.txt <<EOL
flask
EOL

echo "==> Writing Dockerfile..."
cat > app/Dockerfile <<EOL
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
EOL

echo "==> Building Docker image..."
cd app
docker build -t lthawkins48/devops-portfolio:latest .
cd ..

echo "==> Setup complete. Next: ./redeploy.sh"

