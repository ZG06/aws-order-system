# Create the API Gateway resource
resource "aws_apigatewayv2_api" "http_api" {
    name = "${var.project_name}-api-${var.environment}"
    protocol_type = "HTTP"
}

# Connect API Gateway to the compute layer (Lambda)
resource "aws_apigatewayv2_integration" "integration" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY" # Tells API Gateway to take raw HTTP request and send it to Lambda without transforming the payload
  integration_uri = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# Validated the request and sends it to Lambda
resource "aws_apigatewayv2_route" "api_route" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "POST /order"
    target = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

# Deploy the route configuration
resource "aws_apigatewayv2_stage" "name" {
  api_id = aws_apigatewayv2_api.http_api.id
  name = "$default"
  auto_deploy = true
}

# Grant API Gateway permission to call 'lambda:InvokeFunction' on the Lambda function
resource "aws_lambda_permission" "lambda_permission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = var.lambda_function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*" # Only allow this specific API Gateway instance to trigger the Lambda function
}