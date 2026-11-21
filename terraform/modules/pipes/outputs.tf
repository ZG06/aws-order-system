output "pipe_dlq_arn" {
  description = "ARN of the SQS DLQs"
  value       = aws_sqs_queue.pipe_dlq.arn
}