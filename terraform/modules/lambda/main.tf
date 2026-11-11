resource "aws_lambda_function" "order_processor" {
  function_name = "${var.project_name}-lambda-function-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  filename      = "${path.module}/resources/function.zip"
  # Force Terrafrom to deploy updates whenever the binary's hash changes
  source_code_hash = filebase64sha256("${path.module}/resources/function.zip")

  environment {
    variables = {
        TABLE_NAME = var.dynamodb_table_name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.order_processor.function_name}"
  // Deleting old logs after 14 days rather than keeping them indefinitely
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name = "${var.project_name}-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  period = 300
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  statistic = "Sum"
  threshold = 1
  alarm_description = "Triggers when Lambda execution encounters unhandled failures"

  dimensions = {
    FunctionName = aws_lambda_function.order_processor.function_name
  }
}