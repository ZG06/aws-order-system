output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.order_processor.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function for API Gateway integration"
  value       = aws_lambda_function.order_processor.invoke_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.order_processor.function_name
}