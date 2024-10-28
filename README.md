# Market Dashboard Deployment

## Project Structure

```
market_dashboard/
│
├── cicd_workflows/
│   └── deploy.yml
├── containerization/
│   └── Dockerfile
├── README.md
├── sql_scripts/
│   └── solution.sql
├── streamlit_app/
│   ├── main.py
│   ├── requirements.txt
│   ├── utils/
│   │   └── snowflake_utils.py
│   └── widgets/
│       ├── price_history.py
│       ├── top_companies.py
│       └── top_sectors.py
└── terraform/
    ├── main.tf
    └── iam_user.tf
```

## Overview

The Market Dashboard is deployed on AWS using ECS, ECR, and other AWS resources. This document provides instructions for setting up the necessary AWS infrastructure, creating required secrets, and deploying the application.

### Deployment Overview

The deployment of the Market Dashboard will be done in AWS. Before running the deployment, an AWS IAM user needs to be created to allow the CI/CD pipeline to interact with AWS resources such as ECS, ECR, and CloudWatch.

The creation of this AWS IAM user will be done locally using Terraform. This step is required to ensure the proper permissions are assigned securely and consistently.

## Creating an AWS User with Terraform

To create an AWS IAM user for deploying the Market Dashboard, follow these steps:

1. **Install Terraform**:
   - Follow the instructions at [https://learn.hashicorp.com/tutorials/terraform/install-cli](https://learn.hashicorp.com/tutorials/terraform/install-cli) to install Terraform.

2. **Configure AWS CLI** (optional):
   - Make sure you have credentials configured for Terraform to authenticate with AWS.
   ```bash
   aws configure
   ```

3. **Create the IAM User**:
   - A Terraform script (`iam_user.tf`) is provided in the `/terraform` directory. This script creates an AWS IAM user with the necessary permissions to deploy the Market Dashboard.
   - Navigate to the `/terraform` directory and run the following commands:
     
     - **Initialize Terraform**:
       ```bash
       terraform init
       ```
     
     - **Apply Terraform**:
       ```bash
       terraform apply -target=aws_iam_user.market_dashboard_user
       ```
       This will create an `aws_credentials.txt` file containing the **AWS Access Key ID** and **AWS Secret Access Key**. These credentials should be added as GitHub Secrets for CI/CD.

## Adding Secrets to GitHub Repository

This section explains how to add secrets to your GitHub repository. Secrets are used to securely store sensitive information such as API keys, credentials, and access tokens. In this project, we use GitHub Secrets to store credentials for Snowflake and AWS, which are used for deployment and other operations.

### Steps to Add Secrets in GitHub

1. **Navigate to Your GitHub Repository**
   - Go to your GitHub repository (e.g., [market_dashboard](https://github.com/lunasilvestre/market_dashboard)).

2. **Open Repository Settings**
   - Click on the **Settings** tab at the top of your repository.

3. **Access Secrets and Variables**
   - In the left sidebar, scroll down and click on **Secrets and variables** under the **Security** section.
   - Click on **Actions** to view the secrets used by GitHub Actions.

4. **Add a New Secret**
   - Click the **New repository secret** button.
   - You will see a form where you need to add a **Name** and **Value** for the secret.

5. **Define the Secrets**
   - Add the following secrets based on your project requirements:

     - **SNOWFLAKE_USER**: Your Snowflake user name.
     - **SNOWFLAKE_PASSWORD**: The password for the Snowflake user.
     - **SNOWFLAKE_ACCOUNT**: The account identifier for your Snowflake account.
     - **SNOWFLAKE_WAREHOUSE**: The name of the Snowflake warehouse.
     - **SNOWFLAKE_DATABASE**: The name of the Snowflake database.
     - **SNOWFLAKE_SCHEMA**: The name of the Snowflake schema.
     - **AWS_ACCESS_KEY_ID**: Your AWS access key ID.
     - **AWS_SECRET_ACCESS_KEY**: Your AWS secret access key.
     - **AWS_REGION**: The AWS region where the resources will be deployed.

   - For each secret, provide an appropriate **Name** and **Value**, then click **Add secret**.

6. **Verify Secrets**
   - After adding, you can see a list of your secrets. The values are hidden for security purposes, but you can edit or delete them if necessary.

### Important Notes
- **Do Not Hardcode Secrets**: Never hardcode sensitive information directly in your source code. Always use secrets to protect such data.
- **Accessing Secrets in GitHub Actions**: Once secrets are added, they can be accessed in your GitHub Actions workflows using the syntax `${{ secrets.SECRET_NAME }}`.
- **Keep Secrets Updated**: If any credentials change, make sure to update the corresponding secret in GitHub to avoid any disruptions in the workflows.

By using GitHub Secrets, you ensure that sensitive information is handled securely and is only available to workflows with the correct permissions.
