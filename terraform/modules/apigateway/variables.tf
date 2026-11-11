variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "lambda_invoke_arn" {
  type        = string
  description = "Invoke ARN of the Lambda function for API Gateway integration"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function"
}