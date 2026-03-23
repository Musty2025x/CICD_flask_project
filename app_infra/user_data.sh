#!/bin/bash
set -eux

# Redirect all output to log file and syslog for easy debugging
exec > /var/log/user-data.log 2>&1

# ----------------------------------------
# System update & core dependencies
# ----------------------------------------
dnf update -y
dnf install -y git docker nginx

git --version

# ----------------------------------------
# Docker setup
# ----------------------------------------
systemctl start docker
systemctl enable docker

# Wait for Docker to be fully ready instead of arbitrary sleep
timeout 30 bash -c 'until systemctl is-active --quiet docker; do sleep 1; done'

usermod -aG docker ec2-user
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version

# ----------------------------------------
# Nginx reverse proxy config
# ----------------------------------------

# Remove default server block to avoid conflict with our config on port 80
rm -f /etc/nginx/conf.d/default.conf

cat > /etc/nginx/conf.d/cicd-app.conf <<'EON'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EON

nginx -t
systemctl enable nginx
systemctl start nginx

# ----------------------------------------
# Monitoring stack (Prometheus + Grafana)
# ----------------------------------------

MONITORING_DIR=/home/ec2-user/monitoring

# Clone repo pinned to a specific tag/commit for stability
# Update REPO_TAG to the appropriate release before deploying
REPO_URL=https://github.com/SuhaniSharmaJoshi/CICD_flask_project.git
REPO_TAG=main   # TODO: replace with a pinned tag e.g. v1.2.0

CLONE_DIR=$(mktemp -d)
git clone --depth 1 --branch "$REPO_TAG" "$REPO_URL" "$CLONE_DIR"

# Move monitoring config into place
rm -rf "$MONITORING_DIR"
mv "$CLONE_DIR/app_infra/monitoring" "$MONITORING_DIR"
rm -rf "$CLONE_DIR"

chown -R ec2-user:ec2-user "$MONITORING_DIR"
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" \
  "$MONITORING_DIR/prometheus/prometheus.yml"

# Start monitoring stack
cd "$MONITORING_DIR"

docker compose up -d prometheus grafana node-exporter

# ----------------------------------------
# Systemd service to restart monitoring on reboot
# ----------------------------------------
cat > /etc/systemd/system/monitoring.service <<'EOT'
[Unit]
Description=Monitoring Stack (Prometheus + Grafana)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/monitoring
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable monitoring.service

# ----------------------------------------
# Verify running containers (written to log)
# ----------------------------------------
docker ps