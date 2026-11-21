variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "dynamodb_inventory_table_arn" {
  type        = string
  description = "ARN of the DynamoDB inventory table"
}

variable "dynamodb_orders_table_stream_arn" {
  type        = string
  description = "Stream ARN of the DynamoDB orders table"
}

variable "dynamodb_orders_table_arn" {
  type        = string
  description = "ARN of the DynamoDB orders table"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic"
}

variable "pipe_dlq_arn" {
  type        = string
  description = "ARN of the SQS DLQs"
}