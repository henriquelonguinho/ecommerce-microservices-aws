#!/bin/bash
# ─────────────────────────────────────────────
# LocalStack init script — creates AWS resources
# Runs automatically when LocalStack is ready
# ─────────────────────────────────────────────

REGION="us-east-1"

echo "==> Creating SNS topics..."
awslocal sns create-topic --name ecommerce-order-created --region $REGION
awslocal sns create-topic --name ecommerce-payment-completed --region $REGION

echo "==> Creating SQS queues..."
awslocal sqs create-queue --queue-name ecommerce-order-created-dlq --region $REGION
awslocal sqs create-queue --queue-name ecommerce-order-created-queue \
  --attributes '{
    "VisibilityTimeout": "60",
    "ReceiveMessageWaitTimeSeconds": "20",
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:000000000000:ecommerce-order-created-dlq\",\"maxReceiveCount\":\"3\"}"
  }' --region $REGION

awslocal sqs create-queue --queue-name ecommerce-payment-completed-dlq --region $REGION
awslocal sqs create-queue --queue-name ecommerce-payment-completed-queue \
  --attributes '{
    "VisibilityTimeout": "60",
    "ReceiveMessageWaitTimeSeconds": "20",
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:000000000000:ecommerce-payment-completed-dlq\",\"maxReceiveCount\":\"3\"}"
  }' --region $REGION

echo "==> Subscribing SQS queues to SNS topics..."
awslocal sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:000000000000:ecommerce-order-created \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:ecommerce-order-created-queue \
  --region $REGION

awslocal sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:000000000000:ecommerce-payment-completed \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:ecommerce-payment-completed-queue \
  --region $REGION

echo "==> Creating S3 bucket..."
awslocal s3 mb s3://ecommerce-receipts --region $REGION

echo "==> Verifying SES email..."
awslocal ses verify-email-identity --email-address noreply@example.com --region $REGION

echo "==> LocalStack init complete!"
