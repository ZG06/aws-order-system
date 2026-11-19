variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "dynamodb_orders_table_stream_arn" {
  type        = string
  description = "Stream ARN of the DynamoDB orders table"
}

variable "pipe_role_arn" {
  type        = string
  description = "ARN for the EventBridge Pipe role"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic"
}