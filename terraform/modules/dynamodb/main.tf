resource "aws_dynamodb_table" "inventory" {
  name = "${var.project_name}-inventory-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "product_id"
  
  attribute {
    name = "product_id"
    type = "S"
  }
}

// Add sample items to the stock
resource "aws_dynamodb_table_item" "sample_item" {
  table_name = aws_dynamodb_table.inventory.name
  hash_key   = aws_dynamodb_table.inventory.hash_key

  item = <<ITEM
  {
    "product_id": {"S": "prod-101"},
    "stock": {"N": "100"}
  }
  ITEM
}