terraform {
  backend "s3" {
    bucket         = "market-dashboard-terraform-state-1730223462"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "market_dashboard_terraform_lock"
  }
}
