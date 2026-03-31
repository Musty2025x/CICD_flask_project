# CICD Flask App — Full DevOps Pipeline on AWS

A production-style CI/CD pipeline built from scratch. Push code to GitHub and it automatically builds, containerises, and deploys a Flask app to AWS — with real-time monitoring via Prometheus and Grafana.

---

## What This Project Does

Every `git push` to `main` triggers a fully automated pipeline:

1. GitHub Actions builds a Docker image of the Flask app
2. The image is pushed to a private AWS ECR registry
3. GitHub Actions SSHs into the EC2 instance
4. The new container is deployed via Docker Compose
5. Prometheus scrapes live metrics from the app
6. Grafana visualises them on a dashboard

Zero manual steps. Zero hardcoded AWS credentials.

---

## Architecture

```
Developer
    │
    │  git push
    ▼
GitHub Actions
    ├── Build Docker image
    ├── Push to AWS ECR
    └── SSH into EC2
            │
            ▼
        EC2 Instance
        ├── flask-app        ← your app (deployed by pipeline)
        ├── nginx            ← reverse proxy on port 80
        ├── prometheus       ← scrapes metrics every 15s
        ├── grafana          ← dashboards on port 3000
        └── node-exporter    ← EC2 host metrics (CPU, memory, disk)
```

---

## Project Structure

```
.
├── app/
│   ├── app.py              # Flask application
│   ├── Dockerfile        # Container definition
│   └── requirements.txt   # Python dependencies
│
├── app_infra/
│   ├── ec2.tf                        # EC2 instance, security group, EIP
│   ├── iam.tf                        # EC2 IAM role for ECR access
│   ├── main.tf                       # AWS provider config
│   ├── variables.tf                  # Input variables
│   ├── output.tf                     # Elastic IP output
│   ├── user_data.sh                  # EC2 bootstrap script
│   └── monitoring/
│       ├── docker-compose.yml        # All 4 containers
│       └── prometheus/
│           └── prometheus.yml        # Scrape targets config
│
├── terraform/
│   ├── ecr.tf                        # ECR repository
│   ├── iam_role.tf                   # GitHub Actions IAM role
│   ├── oidc.tf                       # GitHub OIDC provider
│   ├── provider.tf                   # AWS provider
│   └── outputs.tf                    # ECR URL, role ARN
│
└── .github/
    └── workflows/
        └── deploy.yml                # CI/CD pipeline definition
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Python, Flask |
| Containerisation | Docker, Docker Compose |
| Image Registry | AWS ECR |
| Infrastructure | AWS EC2, Terraform |
| CI/CD | GitHub Actions |
| Auth (GitHub → AWS) | OIDC (no stored credentials) |
| Reverse Proxy | Nginx |
| Metrics Collection | Prometheus, Node Exporter |
| Visualisation | Grafana |

---

## Prerequisites

- AWS account with appropriate permissions
- Terraform >= 1.2 installed locally
- Docker installed in the host EC2 instance
- GitHub repository with Actions enabled

---

## Setup Guide

### Step 1 — Provision ECR and GitHub Actions IAM role

```bash
cd terraform/
terraform init
terraform apply
```

Note the outputs — you'll need the ECR URL and role ARN.

### Step 2 — Add GitHub Secrets

In your GitHub repo go to Settings → Secrets → Actions and add:

| Secret | Value |
|---|---|
| `EC2_SSH_KEY` | Your EC2 private key (PEM contents) |

The AWS credentials are handled automatically via OIDC — no AWS keys needed.

### Step 3 — Provision EC2 infrastructure

```bash
cd app_infra/
terraform init
terraform apply 
```

This creates the EC2 instance, security group, Elastic IP, and runs `user_data.sh` automatically on first boot. The monitoring stack (Prometheus, Grafana, Node Exporter) starts automatically.

### Step 4 — Update deploy.yml with your EC2 IP

Replace the hardcoded IP in `.github/workflows/deploy.yml` with your Elastic IP from the Terraform output. It is a bad security practice, but for practice projects it is acceptable, in production environment DNS is used in place of IP.

### Step 5 — Push to main

```bash
git push origin main
```

GitHub Actions builds the image, pushes to ECR, and deploys the Flask container. The full pipeline takes about 60 seconds.

---

## Accessing the Services

Once deployed, all services are available via the EC2 public IP:

| Service | URL | Notes |
|---|---|---|
| Flask App | `http://<ec2-ip>` | Served through Nginx on port 80 |
| Prometheus | `http://<ec2-ip>:9090` | Metrics database and query UI |
| Grafana | `http://<ec2-ip>:3000` | Dashboards (default password in docker-compose.yml) |

Port 5000 is intentionally not exposed — Flask is only reachable through Nginx internally.

---

## Monitoring

Prometheus scrapes three targets every 15 seconds:

- `flask-app:5000/metrics` — request counts, latency, error rates per route
- `<private-ip>:9100` — EC2 host metrics via Node Exporter (CPU, memory, disk, network)
- `localhost:9090` — Prometheus self-monitoring

### Recommended Grafana Dashboards

Import these by ID from grafana.com:

- **11159** — Flask application metrics (request rate, latency, error rate)
- **1860** — Node Exporter Full (EC2 CPU, memory, disk, network)

To import: Dashboards → Import → enter ID → select Prometheus data source → Import.

---

## How the Pipeline Works

```
git push main
      │
      ▼
GitHub Actions
      │
      ├─ [1] Checkout code
      ├─ [2] Authenticate to AWS via OIDC (no stored credentials)
      ├─ [3] Login to ECR
      ├─ [4] Build Docker image from app/Dockerfile
      ├─ [5] Tag and push image to ECR
      ├─ [6] SSH into EC2
      │        ├─ Login to ECR
      │        ├─ Pull new image
      │        ├─ docker compose up --no-deps --force-recreate flask-app
      │        └─ Reload Nginx
      │
      ▼
   New version live in ~60 seconds
   Prometheus, Grafana, Node Exporter untouched
```

The `--no-deps` flag ensures only the Flask container is restarted. The monitoring stack keeps running without interruption on every deploy.

---

## Security Notes

- GitHub Actions authenticates to AWS via OIDC — no AWS access keys stored anywhere
- The OIDC trust is scoped to this specific repo and the `main` branch only
- Flask container binds to `127.0.0.1:5000` only — not exposed publicly
- EC2 IAM role has read-only ECR access — principle of least privilege
- Port 5000 is not open in the security group

---

## Key Design Decisions

**Why two separate Terraform configs?**
The ECR repo and GitHub IAM role are one-time foundational setup. The EC2 instance is something you might tear down and recreate regularly. Keeping them separate means you don't accidentally destroy your image registry when re-provisioning the server.

**Why OIDC instead of stored AWS credentials?**
Stored credentials are a security liability — they can be leaked, they don't expire, and they need manual rotation. OIDC tokens are short-lived, automatically rotated, and scoped to a specific repo and branch. Another reason was everytime I destroyed and recreated the instance, I have to store the new value, which was not a fisible solution. 

**Why not start flask-app in user_data.sh?**
At boot time the ECR image doesn't exist yet — GitHub Actions hasn't built it. Starting only the monitoring stack at boot keeps infrastructure and application deployment cleanly separated.

**Why does Node Exporter use host networking?**
Node Exporter needs to read `/proc`, `/sys`, and the root filesystem to report real EC2 metrics. In an isolated container network it would only see its own container's resources, which is meaningless for server monitoring.

**Top queries PromQL- **
CPU usage- 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode = "idle"}[1m]))*100)
Memory Usage - (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
Disk Usage - (node_filesystem_size_bytes - node_filesystem_free_bytes)/node_filesystem_size_bytes * 100 
Network Traffic - 
rate(node_network_receive_bytes_total[1m])
rate(node_network_transmit_bytes_total[1m])
