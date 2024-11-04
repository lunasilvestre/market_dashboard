# Market Dashboard Deployment Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
   - [Pre-requisites](#pre-requisites)
   - [Set Environment Variables](#set-environment-variables)
   - [Setting Up Snowflake](#setting-up-snowflake)
3. [Local Development](#local-development)
   - [Build the Docker Image](#build-the-docker-image)
   - [Run the Docker Container](#run-the-docker-container)
4. [Deploying to AWS](#deploying-to-aws)
   - [Step 1: Base Infrastructure Setup](#step-1-base-infrastructure-setup)
   - [Step 2: Authenticate and Upload Docker Image to ECR](#step-2-authenticate-and-upload-docker-image-to-ecr)
   - [Step 3: Application Deployment](#step-3-application-deployment)
5. [Accessing the Application](#accessing-the-application)
6. [CI/CD Setup](#cicd-setup)
7. [Deploying to AWS](#deploying-to-aws)
8. [Troubleshooting and Tips](#troubleshooting-and-tips)
9. [Next Steps](#next-steps)

## Introduction

This guide explains how to deploy the Market Dashboard application on AWS using Terraform for infrastructure management, Docker for containerizing the application, and GitHub Actions for CI/CD.

The Market Dashboard aggregates data from various sources to provide insights, transforming it, and presenting it in a streamlined dashboard. This solution simulates our development process to provide business intelligence in a production-ready manner.

## Getting Started

### Pre-requisites

- **AWS CLI**: Ensure it's installed and correctly configured.
- **Terraform**: Installed and set up.
- **Docker**: Installed to build and test the application locally.
- **Snowflake Account**: Access credentials for Snowflake to create required tables.
- **GitHub Repository**: A repository to store and manage the source code.

### Set Environment Variables

Before proceeding, complete the `.env` file with your Snowflake credentials and load them as environment variables:

```bash
source ./streamlit/.env
```

### Setting Up Snowflake

After setting the environment variables, set up the Snowflake environment by running the provided SQL scripts ([`ddl.sql`](sql/ddl.sql)). These scripts create views that transform raw data into the necessary format for the Market Dashboard. The views are essential for the Streamlit application to function properly, as they provide the processed data required by the dashboard.

You can either use the Snowflake web console or run the following code to deploy the SQL scripts:

```bash
python - <<EOF
import snowflake.connector

# Replace the following values with your Snowflake credentials
conn = snowflake.connector.connect(
   user="${SNOWFLAKE_USER}",
   password="${SNOWFLAKE_PASSWORD}",
   account="${SNOWFLAKE_ACCOUNT}",
   warehouse="${SNOWFLAKE_WAREHOUSE}",
   database="${SNOWFLAKE_DATABASE}",
   schema="${SNOWFLAKE_SCHEMA}"
)
cursor = conn.cursor()
with open('sql/ddl.sql', 'r') as f:
   ddl = f.read()
cursor.execute(ddl)
cursor.close()
conn.close()
EOF
```

## Local Development

For local testing and development, follow these steps:

### Build the Docker Image

Build your Docker image from the Dockerfile provided (from the root of the repository):

```bash
docker build -t market_dashboard_app -f docker/Dockerfile .
```

### Run the Docker Container

Run the container locally to test the application:

```bash
docker run -e SNOWFLAKE_USER=${SNOWFLAKE_USER} \
           -e SNOWFLAKE_PASSWORD=${SNOWFLAKE_PASSWORD} \
           -e SNOWFLAKE_ACCOUNT=${SNOWFLAKE_ACCOUNT} \
           -e SNOWFLAKE_WAREHOUSE=${SNOWFLAKE_WAREHOUSE} \
           -e SNOWFLAKE_DATABASE=${SNOWFLAKE_DATABASE} \
           -e SNOWFLAKE_SCHEMA=${SNOWFLAKE_SCHEMA} \
           -p 8501:8501 market_dashboard_app
```

Browse to `http://localhost:8501` to view the application.

## Deploying to AWS

This project is deployed in multiple sequential steps using Terraform:

### Step 1: Base Infrastructure Setup

This step sets up the base infrastructure, including:
- AWS user for CI/CD automation
- ECR repository for storing the Docker image
- VPC, subnets, security groups
- CloudWatch log group for ECS tasks

#### Required Variables for Terraform

The `infrastructure_setup` Terraform project requires certain variables to be defined. These variables can be set in a `terraform.tfvars` file or passed during runtime. For details on each variable, see the [`variables.tf`](terraform/infrastructure_setup/variables.tf) file in the project directory.

Example `terraform.tfvars` file (sanitized for public sharing):

```hcl
aws_region          = "YOUR_AWS_REGION"
ci_cd_user_name     = "YOUR_CI_CD_USER_NAME"
s3_bucket_name      = "YOUR_S3_BUCKET_NAME"
dynamodb_table_name = "YOUR_DYNAMODB_TABLE_NAME"
ecr_repository_name = "YOUR_ECR_REPOSITORY_NAME"
environment         = "YOUR_ENVIRONMENT"
```

Make sure to replace the placeholders with your actual values before running Terraform.

#### Permissions Required for AWS User

The AWS user used to deploy the Terraform project in **Step 1** needs to have specific permissions. A JSON file ([`admin_permissions_policy.json`](terraform/infrastructure_setup/admin_permissions_policy.json)) exists in the `terraform/infrastructure_setup` folder, which defines these permissions. These permissions can be added inline using the IAM permissions policy editor in AWS Console and will ensure that the user can create and manage the necessary AWS resources for the deployment.

#### Running Terraform
1. **Navigate to** `terraform/infrastructure_setup`.
2. **Initialize Terraform**:

   ```bash
   terraform init
   ```

3. **Apply the Terraform Configuration**:

   ```bash
   terraform apply -auto-approve
   ```

4. **Terraform Outputs**: After this Terraform deployment, several outputs will be provided, including AWS credentials for CI/CD, subnet IDs, VPC ID, security group IDs, and ECR repository URL. These outputs are necessary for setting up the CI/CD pipeline and should be added as GitHub Secrets if you wish to enable CI/CD automation.

   To retrieve the CI/CD user secret key, run:

   ```bash
   terraform output -raw ci_cd_secret_key
   ```

### Step 2: Authenticate and Upload Docker Image to ECR

The next steps involve using a distinct AWS user with specific permissions, created in Step 1.

#### Step 2.1: Configure AWS CLI

Before proceeding, configure the AWS CLI with the appropriate credentials for the CI/CD AWS user created in Step 1. This user is created with the permissions specified in the [`permissions_policy.json`](terraform/infrastructure_setup/permissions_policy.json) file.

Run the following command and enter the required details:

```bash
aws configure
```

#### Step 2.2: Upload Docker Image to ECR

After configuring the AWS CLI, run the following command to authenticate to the ECR repository and upload the Docker image:

```bash
./docker/ecr_upload.sh
```

### Step 3: Application Deployment

This step sets up the ECS cluster, the Fargate service, and configures the Application Load Balancer (ALB). It will also ouput the public Streamlit application URL.

#### Configure Terraform Backend
The `application_management` Terraform project uses a cloud based backend that simplifies the collaborative development process. This backend is configured in the `terraform/application_management/backend.tf` file and a scafold for this file is provided in the `terraform/application_management` folder as `backend.tf.template`.
This file should be renamed to `backend.tf` and populated with the required values. The values include the S3 bucket name, region, and DynamoDB table name. (In this particular case, these values need to be harcoded and can't be retrieved from Terraform outputs or environment variables.)


#### Required Variables for Terraform

The `application_management` Terraform project requires certain variables to be defined. These variables can be set in a `terraform.tfvars` file or passed during runtime. For details on each variable, see the [`variables.tf`](terraform/application_management/variables.tf) file in the project directory.

Example `terraform.tfvars` file (sanitized for public sharing):

```hcl
aws_region                 = "YOUR_AWS_REGION"
vpc_id                     = "YOUR_VPC_ID"
subnet_ids                 = ["YOUR_SUBNET_ID_1", "YOUR_SUBNET_ID_2"]
alb_security_group_id      = "YOUR_ALB_SECURITY_GROUP_ID"
ecs_task_security_group_id = "YOUR_ECS_TASK_SECURITY_GROUP_ID"
ecr_repository_name        = "YOUR_ECR_REPOSITORY_NAME"
environment                = "YOUR_ENVIRONMENT"
```

Make sure to replace the placeholders with your actual values before running Terraform.

#### Running Terraform
1. **Navigate to** `terraform/application_management`.
2. **Initialize Terraform**:

   ```bash
   terraform init
   ```

3. **Apply the Terraform Configuration**:

   ```bash
   terraform apply -auto-approve
   ```

## Accessing the Application

At the end of the Terraform deployment, you will be provided with the `market_dashboard_url`, which allows you to access the deployed application via the Application Load Balancer.

Example URL:

```
http://market-dashboard-alb-<unique-id>.<aws-region>.elb.amazonaws.com/
```

## CI/CD Setup

To automate the deployment process using GitHub Actions, set up GitHub Secrets with the following variables:

1. **AWS Credentials**:

   1. `AWS_ACCESS_KEY_ID`: Access key ID for the CI/CD user.
   2. `AWS_SECRET_ACCESS_KEY`: Secret key for the CI/CD user.
   3. `AWS_REGION`: Deployment region (e.g., `eu-west-1`).

2. **Snowflake Credentials** (Store these securely):

   1. `SNOWFLAKE_USER`
   2. `SNOWFLAKE_PASSWORD`
   3. `SNOWFLAKE_ACCOUNT`
   4. `SNOWFLAKE_WAREHOUSE`
   5. `SNOWFLAKE_DATABASE`
   6. `SNOWFLAKE_SCHEMA`

3. **Network and Terraform Configuration**:

   1. `VPC_ID`
   2. `SUBNET_IDS`
   3. `ALB_SECURITY_GROUP_ID`
   4. `ECS_TASK_SECURITY_GROUP_ID`
   5. `S3_BUCKET` for Terraform state
   6. `DYNAMODB_TABLE` for state locking

After setting up GitHub Secrets, the deployment can be initiated through GitHub Actions, which will:

- Build the Docker image.
- Push it to Amazon ECR.
- Deploy the infrastructure and application to ECS.

Once the deployment is complete, you will be provided with a URL to access the Market Dashboard application via the Application Load Balancer.

Example:

```
http://market-dashboard-alb-<unique-id>.<aws-region>.elb.amazonaws.com/
```

## Troubleshooting and Tips

- **Application Load Balancer Issues**: Ensure that the security groups allow inbound traffic on port 80.
- **CloudWatch Logs**: The CloudWatch log group should be created before deploying the ECS service to ensure logging works correctly. Check the ECS task role for appropriate permissions to publish logs to CloudWatch if logs are not appearing.
- **Environment Variables**: Ensure all Snowflake credentials are correctly configured and passed to the ECS tasks.

## Next Steps

Now that your infrastructure and application are set up, consider:

- Optimizing autoscaling policies.
- Improving CI/CD workflows.
- Monitoring the application to ensure reliability.
