# 📚 DevOps Portfolio Docs

## 🔗 Project Links
- **GitHub Repo**: [DevOps Portfolio Hub](https://github.com/lthawkins48/devops-portfolio-hub)
- **DockerHub Image**: https://hub.docker.com/r/lthawkins48/devops-portfolio
- **Deployed App**: http://<EC2-PUBLIC-IP>:5000

---

## 🖼️ Deployment Architecture

```mermaid
graph TD
    A[Developer Laptop] -->|git push| B[GitHub Repo]
    B -->|Docker build & push| C[DockerHub Registry]
    D[Terraform] -->|Provision EC2 & SG| E[AWS EC2 Instance]
    C -->|docker pull| E
    E -->|Serve Flask App| F[User Browser: http://EC2-Public-IP:5000]
graph LR
    A[Developer Commit] --> B[GitHub Actions CI/CD]
    B --> C[Build Docker Image]
    C --> D[Push to DockerHub]
    B --> E[Terraform Apply]
    E --> F[AWS EC2 Deployment]
    F --> G[Running Flask App on :5000]

