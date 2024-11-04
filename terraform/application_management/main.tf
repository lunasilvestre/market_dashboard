# Main Terraform configuration for AWS infrastructure related to Market Dashboard Streamlit application

# Define the AWS provider to interact with AWS services
provider "aws" {
  alias  = "primary"
  region = var.aws_region  # The region where all the resources will be deployed
}

# Create ECS Cluster to manage containerized applications
resource "aws_ecs_cluster" "market_dashboard_cluster" {
  name = "market_dashboard_cluster"

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment  # Environment tag, e.g., Development, Production
    ManagedBy   = "Terraform"  # Indicates Terraform is managing this resource
  }  
}

# Define IAM Role for ECS Task Execution, allowing the ECS tasks to make AWS API calls
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment  # Environment tag
    ManagedBy   = "Terraform"  # Indicates Terraform is managing this resource
  }
}

# IAM policy document that defines the permissions to assume the ECS role
# This allows ECS to execute tasks by assuming the role defined above
data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]  # Principal for ECS tasks to assume the role
    }
  }
}

# Attach the ECS Task Execution Policy to the IAM Role
# This policy allows ECS to pull images from ECR and send logs to CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define ECS Task Definition that specifies how containers should be launched
resource "aws_ecs_task_definition" "market_dashboard_task" {
  family                   = "market_dashboard_task"  # Group name for the task definition
  network_mode             = "awsvpc"  # Specifies networking mode for ECS tasks
  requires_compatibilities = ["FARGATE"]  # Run the task using Fargate
  cpu                      = "256"  # vCPU allocation for the task
  memory                   = "512"  # Memory allocation for the task
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  # IAM role for task execution

  # Define the container details for the task
  container_definitions = jsonencode([
    {
      name      = "market_dashboard_app"
      image     = "${var.ecr_repository_url}:latest"  # ECR image URL
      essential = true  # Indicates this container must be running for the task to be healthy
      portMappings = [
        {
          containerPort = 8501  # Port inside the container to expose
          hostPort      = 8501  # Port on the host to expose
        }
      ]
      environment = [
        { name = "SNOWFLAKE_USER", value = var.snowflake_user },
        { name = "SNOWFLAKE_PASSWORD", value = var.snowflake_password },
        { name = "SNOWFLAKE_ACCOUNT", value = var.snowflake_account },
        { name = "SNOWFLAKE_WAREHOUSE", value = var.snowflake_warehouse },
        { name = "SNOWFLAKE_DATABASE", value = var.snowflake_database },
        { name = "SNOWFLAKE_SCHEMA", value = var.snowflake_schema }
      ]
      logConfiguration = {  # Configuring logs to send container output to CloudWatch
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_log_group_name  # CloudWatch log group
          awslogs-region        = var.aws_region  # Region for CloudWatch logs
          awslogs-stream-prefix = "ecs"  # Stream prefix for CloudWatch logs
        }
      }
    }
  ])

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment  # Environment tag
    ManagedBy   = "Terraform"  # Indicates Terraform is managing this resource
  }
}

# Define ECS Fargate Service to run the ECS Task Definition
# resource "aws_ecs_service" "market_dashboard_service" {
#   name            = "market_dashboard_service"
#   cluster         = aws_ecs_cluster.market_dashboard_cluster.id  # Cluster to run the service in
#   task_definition = aws_ecs_task_definition.market_dashboard_task.arn  # Task definition for the service
#   launch_type     = "FARGATE"  # Launch using Fargate

#   network_configuration {
#     subnets         = var.subnet_ids  # Subnets for the service
#     security_groups = [var.security_group_id]  # Security group for the service
#     assign_public_ip = true  # Assign a public IP to the task
#   }


#   load_balancer {
#     target_group_arn = aws_lb_target_group.market_dashboard_tg.arn
#     container_name   = "market_dashboard_app"
#     container_port   = 8501
#   }

#   desired_count = 1  # Number of tasks to run in the service

#   tags = {
#     Project     = "MarketDashboard"
#     Environment = var.environment  # Environment tag
#     ManagedBy   = "Terraform"  # Indicates Terraform is managing this resource
#   }
# }

# Define Autoscaling Target for ECS Fargate Service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5  # Maximum number of tasks to scale up
  min_capacity       = 1  # Minimum number of tasks to scale down
  resource_id        = "service/${aws_ecs_cluster.market_dashboard_cluster.name}/${aws_ecs_service.market_dashboard_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"  # Scale based on desired count of tasks
  service_namespace  = "ecs"  # Namespace for ECS services
}

# Define Autoscaling Policy to scale up the ECS service based on traffic
resource "aws_appautoscaling_policy" "ecs_scale_up" {
  name               = "scale_up_policy"  # Name of the scaling policy
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id  # Resource to scale
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60  # Cooldown period before another scaling action
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0  # Threshold for scaling up
      scaling_adjustment          = 1  # Number of tasks to add
    }
  }
}

# Define Autoscaling Policy to scale down the ECS service when load decreases
resource "aws_appautoscaling_policy" "ecs_scale_down" {
  name               = "scale_down_policy"  # Name of the scaling policy
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id  # Resource to scale
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300  # Cooldown period before another scaling action
    metric_aggregation_type = "Minimum"

    step_adjustment {
      metric_interval_upper_bound = 0  # Threshold for scaling down
      scaling_adjustment          = -1  # Number of tasks to remove
    }
  }
}


resource "aws_lb" "market_dashboard_lb" {
  name               = "market-dashboard-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "aws_lb_target_group" "market_dashboard_tg" {
  name     = "market-dashboard-tg"
  port     = 8501
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "aws_lb_listener" "market_dashboard_listener_http" {
  load_balancer_arn = aws_lb.market_dashboard_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.market_dashboard_tg.arn
  }
}


resource "aws_ecs_service" "market_dashboard_service" {
  name            = "market_dashboard_service"
  cluster         = aws_ecs_cluster.market_dashboard_cluster.id
  task_definition = aws_ecs_task_definition.market_dashboard_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_task_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.market_dashboard_tg.arn
    container_name   = "market_dashboard_app"
    container_port   = 8501
  }

  desired_count = 1

  tags = {
    Project     = "MarketDashboard"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


output "market_dashboard_url" {
  value       = aws_lb.market_dashboard_lb.dns_name
  description = "The URL of the Market Dashboard application."
}
