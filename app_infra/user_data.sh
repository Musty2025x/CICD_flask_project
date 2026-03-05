#!/bin/bash
set -eux

# Update system
dnf update -y

# Install Docker
dnf install -y docker

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Allow ec2-user to run docker without sudo
usermod -aG docker ec2-user

# Install Git (optional but useful)
dnf install -y git

# Install AWS CLI v2 (usually preinstalled, but safe)
dnf install -y awscli

# Create app directory
mkdir -p /home/ec2-user/app
chown ec2-user:ec2-user /home/ec2-user/app

echo "User data setup completed"