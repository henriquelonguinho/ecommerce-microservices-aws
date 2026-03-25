# ─────────────────────────────────────────────
# SQS Queues + Dead Letter Queues
# ─────────────────────────────────────────────

# DLQ for order-created queue
resource "aws_sqs_queue" "order_created_dlq" {
  name                      = "${var.project_name}-order-created-dlq"
  message_retention_seconds = 1209600 # 14 days
  tags                      = var.tags
}

# Main queue: payment-service listens for OrderCreated events
resource "aws_sqs_queue" "order_created" {
  name                       = "${var.project_name}-order-created-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_created_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

# DLQ for payment-completed queue
resource "aws_sqs_queue" "payment_completed_dlq" {
  name                      = "${var.project_name}-payment-completed-dlq"
  message_retention_seconds = 1209600
  tags                      = var.tags
}

# Main queue: notification-service listens for PaymentCompleted events
resource "aws_sqs_queue" "payment_completed" {
  name                       = "${var.project_name}-payment-completed-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payment_completed_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

# ─────────────────────────────────────────────
# SNS → SQS Subscriptions
# ─────────────────────────────────────────────
resource "aws_sns_topic_subscription" "order_created_to_sqs" {
  topic_arn = aws_sns_topic.order_created.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_created.arn

  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "payment_completed_to_sqs" {
  topic_arn = aws_sns_topic.payment_completed.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.payment_completed.arn

  raw_message_delivery = false
}

# ─────────────────────────────────────────────
# SQS Policies — allow SNS to send messages
# ─────────────────────────────────────────────
resource "aws_sqs_queue_policy" "order_created_policy" {
  queue_url = aws_sqs_queue.order_created.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.order_created.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_created.arn }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "payment_completed_policy" {
  queue_url = aws_sqs_queue.payment_completed.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.payment_completed.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.payment_completed.arn }
      }
    }]
  })
}
