// Creates an EventBridge Pipe to receive DynamoDB streams, format the message and publish it through SNS
resource "aws_pipes_pipe" "orders_to_sns" {
  name     = "${var.project_name}-orders-pipe-${var.environment}"
  role_arn = var.pipe_role_arn
  source   = var.dynamodb_orders_table_stream_arn
  target   = var.sns_topic_arn
  source_parameters {
    dynamodb_stream_parameters {
      starting_position = "LATEST"
      batch_size        = 1
    }
    filter_criteria {
      filter {
        pattern = jsonencode({
          eventName = ["INSERT"]
        })
      }
    }
  }
  target_parameters {
    input_template = <<-EOT
      New Order Received!
      Order ID: <$.dynamodb.NewImage.order_id.S>
      Product ID: <$.dynamodb.NewImage.product_id.S>
      Quantity: <$.dynamodb.NewImage.quantity.N>
      Time: <$.dynamodb.NewImage.order_time.S>
    EOT
  }
}