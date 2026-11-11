output "order_api_url" {
  description = "Live URL for sending order payloads"
  value       = module.apigateway.api_endpoint
}