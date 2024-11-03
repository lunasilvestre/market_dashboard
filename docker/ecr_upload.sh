#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Set AWS region (ensure this is set in your environment or script context)
AWS_REGION="${AWS_REGION:-eu-west-1}"

# Retrieve AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Authenticate to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build Docker image
docker build -t market_dashboard_app -f docker/Dockerfile .

# Tag Docker image
docker tag market_dashboard_app:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/market_dashboard_app:latest

# Push Docker image to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/market_dashboard_app:latest

echo "Docker image successfully pushed to ECR repository."
