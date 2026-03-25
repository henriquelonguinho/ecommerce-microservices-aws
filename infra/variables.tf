variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "ecommerce"
}

variable "service_names" {
  description = "List of microservice names"
  type        = list(string)
  default     = ["order-service", "payment-service", "notification-service"]
}

variable "ses_from_email" {
  description = "Verified SES email address for sending notifications"
  type        = string
  default     = "noreply@example.com"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "ecommerce-microservices"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
