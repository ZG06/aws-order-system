variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "dynamodb_table_arn" {
  type = string
  description = "ARN of the DynamoDB table"
}