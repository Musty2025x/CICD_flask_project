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

#login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 455025093404.dkr.ecr.us-east-1.amazonaws.com

#pull docker image
docker pull 455025093404.dkr.ecr.us-east-1.amazonaws.com/cicd-python-app:latest

#run container
docker run -d -p 80:5000 455025093404.dkr.ecr.us-east-1.amazonaws.com/cicd-python-app:latest