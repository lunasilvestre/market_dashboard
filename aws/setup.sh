#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Set variables
IAM_USER_NAME="market-dashboard-user"
S3_BUCKET_NAME="market-dashboard-terraform-state-$(date +%s)"
DYNAMODB_TABLE_NAME="market_dashboard_terraform_lock"
AWS_REGION="eu-west-1"
ECR_REPOSITORY_NAME="market_dashboard_app"

# Function to check if IAM user exists
user_exists() {
  aws iam get-user --user-name $IAM_USER_NAME >/dev/null 2>&1
}

# Function to check if S3 bucket exists
bucket_exists() {
  aws s3api head-bucket --bucket $1 >/dev/null 2>&1
}

# Function to check if DynamoDB table exists
dynamodb_table_exists() {
  aws dynamodb describe-table --table-name $1 >/dev/null 2>&1
}

# Function to check if VPC exists
vpc_exists() {
  aws ec2 describe-vpcs --vpc-ids $1 >/dev/null 2>&1
}

# Function to check if Subnet exists
subnet_exists() {
  aws ec2 describe-subnets --subnet-ids $1 >/dev/null 2>&1
}

# Function to check if Security Group exists
security_group_exists() {
  aws ec2 describe-security-groups --group-ids $1 >/dev/null 2>&1
}

# Function to check if ECR repository exists
ecr_repository_exists() {
  aws ecr describe-repositories --repository-names $1 >/dev/null 2>&1
}

# Create IAM User if it does not exist
if user_exists; then
  echo "IAM User $IAM_USER_NAME already exists. Skipping creation."
else
  aws iam create-user --user-name $IAM_USER_NAME
  echo "IAM User created: $IAM_USER_NAME"
fi

# Attach policies to IAM User (using least permissions principle)
aws iam put-user-policy --user-name $IAM_USER_NAME --policy-name "MarketDashboardPolicy" --policy-document file://permissions_policy.json

# Create access keys for the IAM User if they do not exist
if user_exists; then
  aws iam list-access-keys --user-name $IAM_USER_NAME | jq -e '.AccessKeyMetadata | length == 0' >/dev/null 2>&1 && {
    aws iam create-access-key --user-name $IAM_USER_NAME > aws_credentials.json
    echo "Access keys saved in aws_credentials.json"
  } || {
    echo "Access keys already exist for IAM User $IAM_USER_NAME. Skipping creation."
  }
fi

# Create S3 Bucket if it does not exist
if bucket_exists $S3_BUCKET_NAME; then
  echo "S3 Bucket $S3_BUCKET_NAME already exists. Skipping creation."
else
  aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
  echo "S3 Bucket created: $S3_BUCKET_NAME"
  # Enable versioning on the S3 bucket
  aws s3api put-bucket-versioning --bucket $S3_BUCKET_NAME --versioning-configuration Status=Enabled
  echo "Versioning enabled on S3 Bucket $S3_BUCKET_NAME"
fi

# Create DynamoDB table if it does not exist
if dynamodb_table_exists $DYNAMODB_TABLE_NAME; then
  echo "DynamoDB Table $DYNAMODB_TABLE_NAME already exists. Skipping creation."
else
  aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE_NAME \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  echo "DynamoDB Table created: $DYNAMODB_TABLE_NAME"
fi

# Create VPC if it does not exist
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=market-dashboard-vpc" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" == "None" ]; then
  VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
  aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=market-dashboard-vpc
  echo "VPC created with ID: $VPC_ID"
else
  echo "VPC $VPC_ID already exists. Skipping creation."
fi

# Create Subnets if they do not exist
SUBNET_ID_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=market-dashboard-subnet-1" --query 'Subnets[0].SubnetId' --output text)
if [ "$SUBNET_ID_1" == "None" ]; then
  SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a --query 'Subnet.SubnetId' --output text)
  aws ec2 create-tags --resources $SUBNET_ID_1 --tags Key=Name,Value=market-dashboard-subnet-1
  echo "Subnet 1 created with ID: $SUBNET_ID_1"
else
  echo "Subnet 1 $SUBNET_ID_1 already exists. Skipping creation."
fi

SUBNET_ID_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=market-dashboard-subnet-2" --query 'Subnets[0].SubnetId' --output text)
if [ "$SUBNET_ID_2" == "None" ]; then
  SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b --query 'Subnet.SubnetId' --output text)
  aws ec2 create-tags --resources $SUBNET_ID_2 --tags Key=Name,Value=market-dashboard-subnet-2
  echo "Subnet 2 created with ID: $SUBNET_ID_2"
else
  echo "Subnet 2 $SUBNET_ID_2 already exists. Skipping creation."
fi

# Create Security Group if it does not exist
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=market-dashboard-sg" --query 'SecurityGroups[0].GroupId' --output text)
if [ "$SECURITY_GROUP_ID" == "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
  echo "Creating Security Group market-dashboard-sg..."
  SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name market-dashboard-sg --description "Security group for ECS tasks" --vpc-id $VPC_ID --query 'GroupId' --output text)
  if [ -n "$SECURITY_GROUP_ID" ]; then
    aws ec2 create-tags --resources $SECURITY_GROUP_ID --tags Key=Name,Value=market-dashboard-sg
    echo "Security Group created with ID: $SECURITY_GROUP_ID"
    # Add ingress rule to allow HTTP access
    echo "Adding ingress rule to allow HTTP access on port 8501..."
    EXISTING_RULE=$(aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID --query "SecurityGroups[0].IpPermissions[?ToPort==\`8501\` && FromPort==\`8501\` && IpProtocol==\`tcp\`]" --output text)
    if [ -z "$EXISTING_RULE" ]; then
      aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8501 --cidr 0.0.0.0/0
      echo "Ingress rule added to Security Group $SECURITY_GROUP_ID"
    else
      echo "Ingress rule already exists for Security Group $SECURITY_GROUP_ID. Skipping addition."
    fi
  else
    echo "Error: Failed to create Security Group."
    exit 1
  fi
else
  echo "Security Group $SECURITY_GROUP_ID already exists. Skipping creation."
fi

# Create ECR Repository if it does not exist
if ecr_repository_exists $ECR_REPOSITORY_NAME; then
  echo "ECR Repository $ECR_REPOSITORY_NAME already exists. Skipping creation."
else
  aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION --tags Key=Name,Value=market_dashboard_app Key=Project,Value=MarketDashboard Key=Environment,Value=Production
  echo "ECR Repository created: $ECR_REPOSITORY_NAME"
fi
