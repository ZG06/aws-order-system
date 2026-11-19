output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "pipe_role_arn" {
  description = "ARN of the EventBridge Pipe role"
  value       = aws_iam_role.notifications_role.arn
  // Wait for the policy to be attached to the role
  depends_on = [aws_iam_role_policy_attachment.notifications_attachment]
}