terraform {
  backend "s3" {
    bucket         = "market-dashboard-terraform-state-1"
    key            = "market_dashboard/application_management/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "market-dashboard-terraform-lock"
  }
}
