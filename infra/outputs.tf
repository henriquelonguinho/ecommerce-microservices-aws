output "alb_dns_name" {
  description = "ALB DNS name to access the order-service API"
  value       = aws_lb.main.dns_name
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "order_created_topic_arn" {
  description = "SNS topic ARN for OrderCreated events"
  value       = aws_sns_topic.order_created.arn
}

output "payment_completed_topic_arn" {
  description = "SNS topic ARN for PaymentCompleted events"
  value       = aws_sns_topic.payment_completed.arn
}

output "receipts_bucket" {
  description = "S3 bucket name for receipts"
  value       = aws_s3_bucket.receipts.id
}
