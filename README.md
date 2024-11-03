# Market Dashboard Deployment Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Pre-requisites](#pre-requisites)
3. [Initial Setup](#initial-setup)
4. [Creating CI/CD User and Network Infrastructure](#creating-cicd-user-and-network-infrastructure)
5. [Setting Up GitHub Secrets](#setting-up-github-secrets)

## Introduction
This guide explains how to deploy the Market Dashboard application on AWS, using Terraform for infrastructure management, Docker for containerizing the application, and GitHub Actions for CI/CD.

<<local deployment>>
Build the Docker Image: Build your Docker image from your Dockerfile.
```bash
docker build -t market_dashboard_app -f docker/Dockerfile .
```

Fill in `.env` file with Snowflake credentials and add them as environment variables.
```bash
source streamlit/.env
```

Run docker image locally for testing:
```bash
docker run -e SNOWFLAKE_USER=${{SNOWFLAKE_USER}} \
            -e SNOWFLAKE_PASSWORD=${{SNOWFLAKE_PASSWORD}} \
            -e SNOWFLAKE_ACCOUNT=${{SNOWFLAKE_ACCOUNT}} \
            -e SNOWFLAKE_WAREHOUSE=${{SNOWFLAKE_WAREHOUSE}} \
            -e SNOWFLAKE_DATABASE=${{SNOWFLAKE_DATABASE}} \
            -e SNOWFLAKE_SCHEMA=${{SNOWFLAKE_SCHEMA}} \
            -p 8501:8501 market_dashboard_app
```

Browse `http://localhost:8501` to view the application.


<<AWS ECS deployment>>
[Build and push image to ECR](#build-and-push-image-to-ecr)

1. Build the Docker image

2. Log in to Amazon ECR: Log in to the Amazon ECR from your terminal. This command will allow Docker to interact with your ECR repository:
```bash
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 636901251658.dkr.ecr.eu-west-1.amazonaws.com
```

3. Tag the Docker Image: Tag the Docker image to point to your ECR repository.
```bash
docker tag market_dashboard_app:latest 636901251658.dkr.ecr.eu-west-1.amazonaws.com/market_dashboard_app:latest
```
(Explain which ECR repository the docker image should be pushed to.)

4. Push the Docker Image to ECR: Push the Docker image to the ECR repository.
```bash
docker push 636901251658.dkr.ecr.eu-west-1.amazonaws.com/market_dashboard_app:latest
```




## Pre-requisites
- AWS CLI installed and configured.
- Terraform installed.
- AWS account with permissions to create IAM users, S3 buckets, DynamoDB tables, and network resources (VPC, subnets, security groups).
- GitHub repository for the project.

## Initial Setup
Before deploying the solution, several infrastructure components need to be created through automated scripts to ensure that the CI/CD pipeline runs smoothly.

## Creating CI/CD User and Network Infrastructure
This step involves creating an IAM user for CI/CD, setting up the Terraform backend, and configuring the network infrastructure.

1. **Run the Setup Script**:
   - Use the `setup.sh` script to create the required infrastructure components. The script will:
     - Create the CI/CD IAM user (`market-dashboard-user`).
     - Create an S3 bucket for storing Terraform state.
     - Create a DynamoDB table for Terraform state locking.
     - Create the VPC, subnets, and security group for the application.

   ```bash
   ./setup.sh
   ```

2. **IAM User for CI/CD**:
   - The IAM user created by the script is used by GitHub Actions to deploy resources.
   - The access keys for this user are stored in `aws_credentials.json`. Ensure these are kept secure and not committed to version control.

3. **Network Infrastructure**:
   - The setup script will create a VPC, subnets, and a security group. These resources are used by the ECS services deployed via Terraform.

## Setting Up GitHub Secrets
To enable GitHub Actions to deploy the infrastructure, the following secrets need to be configured in your GitHub repository:

1. **AWS Credentials**:
   - `AWS_ACCESS_KEY_ID`: The access key ID from `aws_credentials.json`.
   - `AWS_SECRET_ACCESS_KEY`: The secret access key from `aws_credentials.json`.
   - `AWS_REGION`: The region where the infrastructure will be deployed.

2. **Snowflake Credentials**:
   - `SNOWFLAKE_USER`: Your Snowflake user.
   - `SNOWFLAKE_PASSWORD`: Your Snowflake password.
   - `SNOWFLAKE_ACCOUNT`: Your Snowflake account identifier.
   - `SNOWFLAKE_WAREHOUSE`: The warehouse used in Snowflake.
   - `SNOWFLAKE_DATABASE`: The database name in Snowflake.
   - `SNOWFLAKE_SCHEMA`: The schema name in Snowflake.

3. **Network and Terraform Configuration**:
   - `VPC_ID`: The ID of the VPC created by the setup script.
   - `SUBNET_IDS`: Comma-separated list of subnet IDs created by the setup script.
   - `SECURITY_GROUP_ID`: The security group ID created by the setup script.
   - `S3_BUCKET`: The name of the S3 bucket for Terraform state.
   - `DYNAMODB_TABLE`: The name of the DynamoDB table for Terraform state locking.

To add a secret to your GitHub repository:
1. Go to your repository on GitHub.
2. Click on **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
3. Add each of the above secrets one by one.

## Next Steps
Once the initial setup is complete, proceed to deploy the Streamlit application using Terraform and GitHub Actions. Refer to the [CI/CD Pipeline Setup](#cicd-pipeline-setup) section for more details.
