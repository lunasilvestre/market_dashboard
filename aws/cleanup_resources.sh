#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Set variables
IAM_USER_NAME="market-dashboard-user"
DYNAMODB_TABLE_NAME="market_dashboard_terraform_lock"
ECR_REPOSITORY_NAME="market_dashboard_app"
AWS_REGION="eu-west-1"

# Function to check if IAM user exists
user_exists() {
  aws iam get-user --user-name $IAM_USER_NAME >/dev/null 2>&1
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

# Delete IAM User
if user_exists; then
  # Detach policies and delete access keys
  echo "Deleting IAM user $IAM_USER_NAME..."
  ACCESS_KEYS=$(aws iam list-access-keys --user-name $IAM_USER_NAME --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  for KEY in $ACCESS_KEYS; do
    aws iam delete-access-key --user-name $IAM_USER_NAME --access-key-id $KEY
  done
  aws iam delete-user-policy --user-name $IAM_USER_NAME --policy-name "MarketDashboardPolicy"
  aws iam delete-user --user-name $IAM_USER_NAME
  echo "IAM User $IAM_USER_NAME deleted."
else
  echo "IAM User $IAM_USER_NAME does not exist. Skipping deletion."
fi

# Delete DynamoDB Table
if dynamodb_table_exists $DYNAMODB_TABLE_NAME; then
  echo "Deleting DynamoDB Table $DYNAMODB_TABLE_NAME..."
  aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME
  echo "DynamoDB Table $DYNAMODB_TABLE_NAME deleted."
else
  echo "DynamoDB Table $DYNAMODB_TABLE_NAME does not exist. Skipping deletion."
fi

# Delete S3 Buckets with "market_dashboard_app" tag
echo "Searching for S3 buckets with tag 'market_dashboard_app'..."
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
for BUCKET in $BUCKETS; do
  TAGS=$(aws s3api get-bucket-tagging --bucket $BUCKET --query 'TagSet' --output json 2>/dev/null || echo "[]")
  if echo $TAGS | jq -e '.[] | select(.Key == "Name" and .Value == "market_dashboard_app")' >/dev/null; then
    echo "Deleting S3 Bucket $BUCKET..."
    aws s3 rb s3://$BUCKET --force
    echo "S3 Bucket $BUCKET deleted."
  fi
done

# Delete VPC, Subnets, and Security Group
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=market-dashboard-vpc" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" != "None" ]; then
  echo "Deleting resources associated with VPC $VPC_ID..."

  # Delete Subnets
  SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
  for SUBNET in $SUBNETS; do
    echo "Deleting Subnet $SUBNET..."
    aws ec2 delete-subnet --subnet-id $SUBNET
    echo "Subnet $SUBNET deleted."
  done

  # Delete Security Group
  SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=market-dashboard-sg" --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$SECURITY_GROUP_ID" != "None" ]; then
    echo "Deleting Security Group $SECURITY_GROUP_ID..."
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID
    echo "Security Group $SECURITY_GROUP_ID deleted."
  fi

  # Delete VPC
  echo "Deleting VPC $VPC_ID..."
  aws ec2 delete-vpc --vpc-id $VPC_ID
  echo "VPC $VPC_ID deleted."
else
  echo "VPC $VPC_ID does not exist. Skipping deletion."
fi

# Delete ECR Repository
if ecr_repository_exists $ECR_REPOSITORY_NAME; then
  echo "Deleting ECR Repository $ECR_REPOSITORY_NAME..."
  aws ecr delete-repository --repository-name $ECR_REPOSITORY_NAME --force
  echo "ECR Repository $ECR_REPOSITORY_NAME deleted."
else
  echo "ECR Repository $ECR_REPOSITORY_NAME does not exist. Skipping deletion."
fi
