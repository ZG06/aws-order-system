resource "aws_sqs_queue" "pipe_dlq" {
  name = "${var.project_name}-pipe-dlq-${var.environment}"
  // Store failed messages for 14 days
  message_retention_seconds = 1209600
}

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
      // Retry attempts for failed attempts to publish a topic to SNS
      maximum_retry_attempts = 3

      dead_letter_config {
        arn = aws_sqs_queue.pipe_dlq.arn
      }
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

// CloudWatch Alarm to check for failed order events entering the DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name = "${var.project_name}-dlq-alarm-${var.environment}"
  // Fire each time a new message enters the DLQ
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  // Check a 1-minute block every minute
  evaluation_periods = 1
  period             = 60
  statistic          = "Maximum"
  metric_name        = "ApproximateNumberOfMessagesVisible"
  namespace          = "AWS/SQS"
  alarm_description  = "SQS DLQ Failed Order Email Notifications"
  // Send an alarm email if an order notification fails
  alarm_actions = [var.sns_topic_arn]
  // Treat the lack of messages in DLQ as a non-error situation
  treat_missing_data = "notBreaching"
  dimensions = {
    // Specify the queue name to monitor
    QueueName = aws_sqs_queue.pipe_dlq.name
  }
}