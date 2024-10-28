provider "aws" {
  region = "eu-south-2" # Replace with your desired region
}

resource "aws_iam_user" "market_dashboard_user" {
  name = "market_dashboard_user"

  tags = {
    Project   = "MarketDashboard"
    ManagedBy = "Terraform"
    Environment = "Production"
  }
}

resource "aws_iam_user_policy_attachment" "attach_policies" {
  count      = length(var.policy_arns)
  user       = aws_iam_user.market_dashboard_user.name
  policy_arn = var.policy_arns[count.index]
}

resource "aws_iam_access_key" "user_key" {
  user = aws_iam_user.market_dashboard_user.name
}

output "aws_access_key_id" {
  value = aws_iam_access_key.user_key.id
}

output "aws_secret_access_key" {
  value     = aws_iam_access_key.user_key.secret
  sensitive = true
}

variable "policy_arns" {
  type    = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]
}

resource "local_sensitive_file" "access_key_output" {
  sensitive_content = <<EOF
  Access Key ID: ${aws_iam_access_key.user_key.id}
  Secret Access Key: ${aws_iam_access_key.user_key.secret}
  EOF

  filename = "${path.module}/aws_credentials.txt"
}
