// Creates a pub/sub messaging channel
resource "aws_sns_topic" "order_alerts" {
  name = "${var.project_name}-order-alerts-${var.environment}"
}

// Registers the given email as a subscriber to the order_alerts topic
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.order_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}