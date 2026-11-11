terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

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
  project_name       = var.project_name
  environment        = var.environment
  dynamodb_table_arn = module.dynamodb.dynamodb_table_arn
}

module "lambda" {
  source = "./modules/lambda"

  # Pass root variables into module parameters
  project_name        = var.project_name
  environment         = var.environment
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.dynamodb.dynamodb_table_name
}

module "apigateway" {
  source = "./modules/apigateway"

  # Pass root variables into module parameters
  project_name         = var.project_name
  environment          = var.environment
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
}