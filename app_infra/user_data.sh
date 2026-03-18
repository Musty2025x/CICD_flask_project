#!/bin/bash
set -eux

# Update system
dnf update -y

#install git
sudo dnf install -y git || {echo "Git install failed"; exit 1;}
git --version
sleep 5
# Install Docker
dnf install -y docker

# Start and enable Docker
systemctl start docker
sleep 10
systemctl enable docker

# Allow ec2-user to run docker without sudo
usermod -aG docker ec2-user
sudo dnf install -y docker-compose-plugin

#login to ECR
#aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 455025093404.dkr.ecr.us-east-1.amazonaws.com

#pull docker image
#docker pull 455025093404.dkr.ecr.us-east-1.amazonaws.com/cicd-python-app:latest

#run container
#docker run -d -p 80:5000 455025093404.dkr.ecr.us-east-1.amazonaws.com/cicd-python-app:latest

#install Nginx
sudo dnf install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

#Nginx Reverse Proxy Default COnfig
sudo bash -c 'cat > /etc/nginx/conf.d/cicd-app.conf <<EON
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;  # Docker container port
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}
EON'

#Test Nginx config and restart

sudo nginx -t
sudo systemctl restart nginx

#monitoring stack
mkdir -p /home/ec2-user/monitoring/prometheus
mkdir -p /home/ec2-user/monitoring/grafana/dashboards

# Copy prometheus.yml and dashboards (from GitHub repo or S3)
# Example using GitHub:
cd /home/ec2-user
git clone https://github.com/SuhaniSharmaJoshi/CICD_flask_project.git temp_repo

mv temp_repo/app_infra/monitoring /home/ec2-user/monitoring
rm -rf temp_repo
# Give ownership to ec2-user
chown -R ec2-user:ec2-user /home/ec2-user/monitoring

# -----------------------------
# Start Monitoring Stack
# -----------------------------
cd /home/ec2-user/monitoring

docker compose up -d

# Optional: Enable monitoring containers on EC2 reboot
cat <<EOT >> /etc/systemd/system/monitoring.service
[Unit]
Description=Monitoring Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=/home/ec2-user/monitoring
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable monitoring.service
systemctl start monitoring.service

docker ps
