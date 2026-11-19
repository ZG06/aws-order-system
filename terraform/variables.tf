variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "AWS environment"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "AWS project name"
  default     = "order-system"
}

variable "alert_email" {
  type        = string
  description = "Email address for order alerts"
  sensitive   = true
}