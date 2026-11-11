variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "lambda_role_arn" {
  type = string
  description = "ARN of the Lambda execution role"
}

variable "dynamodb_table_name" {
  type = string
  description = "Name of the DynamoDB table"
}