variable "project_name" {
  type        = string
  description = "Project name passed from root module"
}

variable "environment" {
  type        = string
  description = "Execution environment passed from root module"
}

variable "alert_email" {
  type        = string
  description = "Email address for order alerts"
  sensitive   = true
}