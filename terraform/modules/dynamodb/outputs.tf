output "dynamodb_inventory_table_arn" {
    description = "ARN of the DynamoDB inventory table"
    value = aws_dynamodb_table.inventory.arn
}

output "dynamodb_inventory_table_name" {
  description = "Name of the DynamoDB inventory table"
  value = aws_dynamodb_table.inventory.name
}

output "dynamodb_orders_table_arn" {
    description = "ARN of the DynamoDB orders table"
    value = aws_dynamodb_table.orders.arn
}

output "dynamodb_orders_table_stream_arn" {
    description = "Stream ARN of the DynamoDB orders table"
    value = aws_dynamodb_table.orders.stream_arn
}

output "dynamodb_orders_table_name" {
  description = "Name of the DynamoDB orders table"
  value = aws_dynamodb_table.orders.name
}