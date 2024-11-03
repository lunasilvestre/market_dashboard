variable "aws_region" {
  description = "The AWS region where the resources will be deployed"
  type        = string
  default     = null
}

variable "aws_account_id" {
  description = "The AWS Account ID to be used for referencing ECR repository"
  type        = string
}

variable "environment" {
  description = "Environment in which the resources will be deployed, e.g., Development, Production"
  type        = string
  default     = "Production"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository to store Docker images"
  type        = string
  default     = "market_dashboard_app"
}

variable "ecr_repository_url" {
  description = "URL of the Docker image on the ECR repository"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to use for the ECS cluster"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of Subnet IDs to use for ECS services"
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "Security Group ID for ECS tasks"
  type        = string
  default     = null
}

variable "snowflake_user" {
  description = "Snowflake user"
  type        = string
  default     = null
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  default     = null
}

variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = null
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse to use for queries"
  type        = string
  default     = null
}

variable "snowflake_database" {
  description = "Snowflake database name to be used"
  type        = string
  default     = null
}

variable "snowflake_schema" {
  description = "Snowflake schema name to be used"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket for storing Terraform state"
  type        = string
  default     = null
}

variable "dynamodb_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = null
}
