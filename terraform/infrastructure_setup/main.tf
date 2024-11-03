# Main Terraform configuration for setting up AWS infrastructure for Market Dashboard Streamlit application

provider "aws" {
  alias  = "primary"
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "market_dashboard_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "market-dashboard-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "market_dashboard_igw" {
  vpc_id = aws_vpc.market_dashboard_vpc.id
  tags = {
    Name = "market-dashboard-igw"
  }
}

# Create Public Route Table
resource "aws_route_table" "market_dashboard_public_rt" {
  vpc_id = aws_vpc.market_dashboard_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.market_dashboard_igw.id
  }
  tags = {
    Name = "market-dashboard-public-rt"
  }
}

# Create Subnets (Public)
resource "aws_subnet" "market_dashboard_subnet_1" {
  vpc_id                  = aws_vpc.market_dashboard_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "market-dashboard-subnet-1"
  }
}

resource "aws_subnet" "market_dashboard_subnet_2" {
  vpc_id                  = aws_vpc.market_dashboard_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "market-dashboard-subnet-2"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.market_dashboard_subnet_1.id
  route_table_id = aws_route_table.market_dashboard_public_rt.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.market_dashboard_subnet_2.id
  route_table_id = aws_route_table.market_dashboard_public_rt.id
}

# Create Security Group
resource "aws_security_group" "market_dashboard_sg" {
  vpc_id = aws_vpc.market_dashboard_vpc.id
  name   = "market-dashboard-sg"
  description = "Security group for ECS tasks"

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "market-dashboard-sg"
  }
}

# Create NAT Gateway
resource "aws_eip" "market_dashboard_eip" {
  vpc = true
  tags = {
    Name = "market-dashboard-eip"
  }
}

resource "aws_nat_gateway" "market_dashboard_nat" {
  allocation_id = aws_eip.market_dashboard_eip.id
  subnet_id     = aws_subnet.market_dashboard_subnet_1.id
  tags = {
    Name = "market-dashboard-nat"
  }
}

# Create Terraform Backend S3 Bucket
resource "aws_s3_bucket" "market_dashboard_terraform_state" {
  bucket = var.s3_bucket
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "market-dashboard-terraform-state"
  }
}

# Create DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "market_dashboard_terraform_lock" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "market-dashboard-terraform-lock"
  }
}






# Infrastructure Setup Terraform configuration for Market Dashboard Streamlit application

provider "aws" {
  region = var.aws_region
}

# Create IAM User for CI/CD
resource "aws_iam_user" "ci_cd_user" {
  name = var.ci_cd_user_name
}

resource "aws_iam_user_policy" "ci_cd_user_policy" {
  name   = "MarketDashboardPolicy"
  user   = aws_iam_user.ci_cd_user.name
  policy = file("permissions_policy.json")
}

# Create Access Key for CI/CD User
resource "aws_iam_access_key" "ci_cd_access_key" {
  user = aws_iam_user.ci_cd_user.name
}

# Create VPC
resource "aws_vpc" "market_dashboard_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "market-dashboard-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "market_dashboard_igw" {
  vpc_id = aws_vpc.market_dashboard_vpc.id
  tags = {
    Name = "market-dashboard-igw"
  }
}

# Create Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.market_dashboard_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.market_dashboard_igw.id
  }
  tags = {
    Name = "market-dashboard-public-rt"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.market_dashboard_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "market-dashboard-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.market_dashboard_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "market-dashboard-subnet-2"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create Security Group
resource "aws_security_group" "market_dashboard_sg" {
  vpc_id = aws_vpc.market_dashboard_vpc.id

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "market-dashboard-sg"
  }
}

# Create S3 Bucket for Terraform Backend
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.s3_bucket_name
  versioning {
    enabled = true
  }
  tags = {
    Name = "market-dashboard-terraform-state"
  }
}

# Create DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "market-dashboard-terraform-lock"
  }
}

# Output values
output "ci_cd_access_key" {
  value       = aws_iam_access_key.ci_cd_access_key.id
  description = "Access key ID for CI/CD user"
}

output "ci_cd_secret_key" {
  value       = aws_iam_access_key.ci_cd_access_key.secret
  description = "Secret access key for CI/CD user"
  sensitive   = true
}

output "vpc_id" {
  value       = aws_vpc.market_dashboard_vpc.id
  description = "ID of the VPC created"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  description = "IDs of the public subnets created"
}

output "security_group_id" {
  value       = aws_security_group.market_dashboard_sg.id
  description = "ID of the security group created"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state_bucket.bucket
  description = "Name of the S3 bucket created for storing Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_state_lock.name
  description = "Name of the DynamoDB table created for state locking"
}
