terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

  # Store terraform state file in an S3 bucket 
  backend "s3" {
    bucket  = "order-system-terraform-state-storage"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

module "dynamodb" {
  source = "./modules/dynamodb"

  # Pass root variables into module parameters
  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "./modules/iam"

  # Pass root variables into module parameters
  project_name                     = var.project_name
  environment                      = var.environment
  dynamodb_inventory_table_arn     = module.dynamodb.dynamodb_inventory_table_arn
  dynamodb_orders_table_stream_arn = module.dynamodb.dynamodb_orders_table_stream_arn
  dynamodb_orders_table_arn        = module.dynamodb.dynamodb_orders_table_arn
  sns_topic_arn                    = module.sns.sns_topic_arn
  pipe_dlq_arn                     = module.pipes.pipe_dlq_arn
}

module "lambda" {
  source = "./modules/lambda"

  # Pass root variables into module parameters
  project_name                  = var.project_name
  environment                   = var.environment
  lambda_role_arn               = module.iam.lambda_role_arn
  dynamodb_inventory_table_name = module.dynamodb.dynamodb_inventory_table_name
  dynamodb_orders_table_name    = module.dynamodb.dynamodb_orders_table_name
}

module "apigateway" {
  source = "./modules/apigateway"

  # Pass root variables into module parameters
  project_name         = var.project_name
  environment          = var.environment
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
}
module "sns" {
  source = "./modules/sns"

  # Pass root variables into module parameters
  project_name = var.project_name
  environment  = var.environment
  alert_email  = "s1demusic06@gmail.com"
}

module "pipes" {
  source = "./modules/pipes"

  # Pass root variables into module parameters
  project_name                     = var.project_name
  environment                      = var.environment
  dynamodb_orders_table_stream_arn = module.dynamodb.dynamodb_orders_table_stream_arn
  pipe_role_arn                    = module.iam.pipe_role_arn
  sns_topic_arn                    = module.sns.sns_topic_arn
}