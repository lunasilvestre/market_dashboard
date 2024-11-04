variable "aws_region" {
  description = "The AWS region where the resources will be deployed"
  type        = string
  default     = "eu-west-1"
}

variable "ci_cd_user_name" {
  description = "The name of the user used for CI/CD"
  type        = string
  default     = "market-dashboard-user"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket for storing Terraform state"
  type        = string
  default     = null
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table for state locking"
  type        = string
  default     = "market-dashboard-terraform-lock"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository to store Docker images"
  type        = string
  default     = "market_dashboard_app"
}

variable "environment" {
  description = "Environment in which the resources will be deployed, e.g., Development, Production"
  type        = string
  default     = "Production"
}
