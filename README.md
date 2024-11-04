# Market Dashboard Deployment Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Set Environment Variables](#set-environment-variables)
   - [Setting Up Snowflake](#setting-up-snowflake)
3. [Local Development](#local-development)
   - [Build the Docker Image](#build-the-docker-image)
   - [Run the Docker Container](#run-the-docker-container)
4. [Deploying to AWS](#deploying-to-aws)
   - [Step 1: Base Infrastructure Setup](#step-1-base-infrastructure-setup)
     - [Required Variables for Terraform](#required-variables-for-terraform)
     - [Permissions Required for AWS User](#permissions-required-for-aws-user)
     - [Running Terraform](#running-terraform)
   - [Step 2: Authenticate and Upload Docker Image to ECR](#step-2-authenticate-and-upload-docker-image-to-ecr)
     - [Configure AWS CLI](#configure-aws-cli)
     - [Upload Docker Image to ECR](#upload-docker-image-to-ecr)
   - [Step 3: Application Deployment](#step-3-application-deployment)
     - [Configure the Terraform Backend](#configure-the-terraform-backend)
     - [Define Required Terraform Variables](#define-required-terraform-variables)
     - [Deploy the Application Using Terraform](#deploy-the-application-using-terraform)
     - [Additional Notes and Tips](#additional-notes-and-tips)
     - [Summary](#summary)
5. [Accessing the Application](#accessing-the-application)
6. [CI/CD Setup](#cicd-setup)
7. [Troubleshooting and Tips](#troubleshooting-and-tips)
8. [Next Steps](#next-steps)

## Introduction

This guide explains how to deploy the Market Dashboard application on AWS using Terraform for infrastructure management, Docker for containerizing the application, and GitHub Actions for CI/CD.

The Market Dashboard aggregates data from various sources to provide insights, transforming it, and presenting it in a streamlined dashboard. This solution simulates our development process to provide business intelligence in a production-ready manner.

## Getting Started

### Prerequisites

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

After setting the environment variables, set up the Snowflake environment by running the provided SQL scripts (`ddl.sql`). These scripts create views that transform raw data into the necessary format for the Market Dashboard. The views are essential for the Streamlit application to function properly, as they provide the processed data required by the dashboard.

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
cursor.execute(ddl, multi=True)
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

The `infrastructure_setup` Terraform project requires certain variables to be defined. These variables can be set in a `terraform.tfvars` file or passed during runtime. For details on each variable, see the `variables.tf` file in the project directory.

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

The AWS user used to deploy the Terraform project in **Step 1** needs to have specific permissions. A JSON file (`admin_permissions_policy.json`) exists in the `terraform/infrastructure_setup` folder, which defines these permissions. These permissions can be added inline using the IAM permissions policy editor in AWS Console and will ensure that the user can create and manage the necessary AWS resources for the deployment.

#### Running Terraform

1. **Navigate to** `terraform/infrastructure_setup`:

   ```bash
   cd terraform/infrastructure_setup
   ```

2. **Initialize Terraform**:

   ```bash
   terraform init
   ```

3. **Apply the Terraform Configuration**:

   ```bash
   terraform apply -auto-approve
   ```

4. **Retrieve Terraform Outputs**:

   After the deployment, several outputs will be provided, including AWS credentials for CI/CD, subnet IDs, VPC ID, security group IDs, and ECR repository URL. These outputs are necessary for setting up the CI/CD pipeline and should be added as GitHub Secrets if you wish to enable CI/CD automation.

   To retrieve the CI/CD user secret key, run:

   ```bash
   terraform output -raw ci_cd_secret_key
   ```

### Step 2: Authenticate and Upload Docker Image to ECR

The next steps involve using a distinct AWS user with specific permissions, created in Step 1.

#### Configure AWS CLI

Before proceeding, configure the AWS CLI with the appropriate credentials for the CI/CD AWS user created in Step 1. This user is created with the permissions specified in the `permissions_policy.json` file.

Run the following command and enter the required details:

```bash
aws configure
```

#### Upload Docker Image to ECR

After configuring the AWS CLI, run the following command to authenticate to the ECR repository and upload the Docker image:

```bash
./docker/ecr_upload.sh
```

### Step 3: Application Deployment

In this step, you will deploy the application to AWS using Terraform. This includes setting up the ECS cluster, Fargate service, and configuring the Application Load Balancer (ALB). Upon completion, you will receive the public URL to access the Streamlit application.

#### Configure the Terraform Backend

The `application_management` Terraform project uses a remote backend to store the Terraform state in an S3 bucket and manage state locking with DynamoDB. This setup facilitates collaboration and ensures state consistency.

**Instructions:**

1. **Navigate to the Backend Configuration Directory**:

   ```bash
   cd terraform/application_management
   ```

2. **Rename the Backend Template File**:

   ```bash
   mv backend.tf.template backend.tf
   ```

3. **Edit the `backend.tf` File**:

   Open `backend.tf` in a text editor and populate it with your backend configuration:

   ```hcl
   terraform {
     backend "s3" {
       bucket         = "YOUR_S3_BUCKET_NAME"
       key            = "YOUR_TERRAFORM_STATE_KEY"
       region         = "YOUR_AWS_REGION"
       dynamodb_table = "YOUR_DYNAMODB_TABLE_NAME"
     }
   }
   ```

   Replace the placeholders with your actual values:

   - `bucket`: The S3 bucket name created in **Step 1** for storing Terraform state.
   - `key`: A unique path within the bucket for the state file (e.g., `"application_management/terraform.tfstate"`).
   - `region`: Your AWS region (e.g., `"us-west-2"`).
   - `dynamodb_table`: The DynamoDB table name created in **Step 1** for state locking.

   **Note:** These values must be hardcoded in the `backend.tf` file and cannot be retrieved from Terraform outputs or environment variables.

#### Define Required Terraform Variables

Before running Terraform, you need to specify certain variables required by the `application_management` project.

**Instructions:**

1. **Create a `terraform.tfvars` File**:

   In the `terraform/application_management` directory, create a file named `terraform.tfvars`.

2. **Populate the `terraform.tfvars` File**:

   ```hcl
   aws_region                 = "YOUR_AWS_REGION"
   vpc_id                     = "YOUR_VPC_ID"
   subnet_ids                 = ["YOUR_SUBNET_ID_1", "YOUR_SUBNET_ID_2"]
   alb_security_group_id      = "YOUR_ALB_SECURITY_GROUP_ID"
   ecs_task_security_group_id = "YOUR_ECS_TASK_SECURITY_GROUP_ID"
   ecr_repository_name        = "YOUR_ECR_REPOSITORY_NAME"
   environment                = "YOUR_ENVIRONMENT"
   ```

   Replace the placeholders with your actual values:

   - `aws_region`: The AWS region for deployment (e.g., `"us-west-2"`).
   - `vpc_id`: The VPC ID created in **Step 1**.
   - `subnet_ids`: A list of subnet IDs within the VPC (obtain from **Step 1** outputs).
   - `alb_security_group_id`: The security group ID for the Application Load Balancer.
   - `ecs_task_security_group_id`: The security group ID for ECS tasks.
   - `ecr_repository_name`: The name of the ECR repository containing your Docker image.
   - `environment`: An identifier for the deployment environment (e.g., `"production"`).

   **Tip:** The values for `vpc_id`, `subnet_ids`, `alb_security_group_id`, and `ecs_task_security_group_id` can be found in the Terraform outputs from **Step 1**. Ensure you have these outputs handy.

#### Deploy the Application Using Terraform

With the backend configured and variables defined, you're ready to deploy the application.

**Instructions:**

1. **Navigate to the Terraform Project Directory** (if not already there):

   ```bash
   cd terraform/application_management
   ```

2. **Initialize Terraform**:

   ```bash
   terraform init
   ```

   This command initializes the project and connects to the remote backend you configured.

3. **Validate the Terraform Configuration** (Optional):

   ```bash
   terraform validate
   ```

   This step checks that your configuration files are syntactically valid and internally consistent.

4. **Preview the Terraform Execution Plan** (Optional but Recommended):

   ```bash
   terraform plan -out=tfplan
   ```

   Review the plan output to understand what resources will be created or modified.

5. **Apply the Terraform Configuration**:

   ```bash
   terraform apply -auto-approve
   ```

   This command will deploy the ECS cluster, Fargate service, and ALB, and will start the application.

6. **Retrieve the Application URL**:

   After the deployment completes, Terraform will output the `market_dashboard_url`. This is the URL to access your deployed Streamlit application via the Application Load Balancer.

   **Example URL:**

   ```
   http://market-dashboard-alb-<unique-id>.<aws-region>.elb.amazonaws.com/
   ```

   **Note:** It may take a few minutes for the ALB to become fully operational after deployment. If the URL does not work immediately, please wait a few minutes and try again.

#### Additional Notes and Tips

- **Security Groups**: Ensure that the security groups associated with the ALB and ECS tasks allow the necessary inbound and outbound traffic. For the ALB, inbound HTTP traffic on port 80 should be allowed.

- **Environment Variables**: Confirm that all necessary environment variables (e.g., Snowflake credentials) are correctly configured and accessible by the ECS tasks. These should be defined in your Terraform configuration or passed securely.

- **Logging and Monitoring**: CloudWatch logs can help you troubleshoot any issues with the ECS tasks. Ensure that the ECS task execution role has the appropriate permissions to write logs to CloudWatch.

- **Resource Cleanup**: If you need to tear down the infrastructure, you can run:

  ```bash
  terraform destroy -auto-approve
  ```

  **Warning**: This will delete all resources created by Terraform. Use with caution.

#### Summary

By completing this step, you have successfully deployed the Market Dashboard application to AWS using ECS Fargate and Terraform. The application is accessible via the public URL provided by the ALB. Proceed to the next sections to set up CI/CD pipelines, monitor your application, and consider further optimizations.

## Accessing the Application

At the end of the Terraform deployment, you will be provided with the `market_dashboard_url`, which allows you to access the deployed application via the Application Load Balancer.

**Example URL**:

```
http://market-dashboard-alb-<unique-id>.<aws-region>.elb.amazonaws.com/
```

## CI/CD Setup

To automate the deployment process using GitHub Actions, set up GitHub Secrets with the following variables:

1. **AWS Credentials**:

   - `AWS_ACCESS_KEY_ID`: Access key ID for the CI/CD user.
   - `AWS_SECRET_ACCESS_KEY`: Secret key for the CI/CD user.
   - `AWS_REGION`: Deployment region (e.g., `us-west-2`).

2. **Snowflake Credentials** (Store these securely):

   - `SNOWFLAKE_USER`
   - `SNOWFLAKE_PASSWORD`
   - `SNOWFLAKE_ACCOUNT`
   - `SNOWFLAKE_WAREHOUSE`
   - `SNOWFLAKE_DATABASE`
   - `SNOWFLAKE_SCHEMA`

3. **Network and Terraform Configuration**:

   - `VPC_ID`
   - `SUBNET_IDS`
   - `ALB_SECURITY_GROUP_ID`
   - `ECS_TASK_SECURITY_GROUP_ID`
   - `S3_BUCKET`: For Terraform state
   - `DYNAMODB_TABLE`: For state locking

After setting up GitHub Secrets, the deployment can be initiated through GitHub Actions, which will:

- Build the Docker image.
- Push it to Amazon ECR.
- Deploy the infrastructure and application to ECS.

Once the deployment is complete, you will be provided with a URL to access the Market Dashboard application via the Application Load Balancer.

**Example**:

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

