# ─────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# ─────────────────────────────────────────────
# CloudWatch Log Groups
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.service_names)

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 30
  tags              = var.tags
}

# ─────────────────────────────────────────────
# ECS Task Execution Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ─────────────────────────────────────────────
# ECS Task Roles (per service)
# ─────────────────────────────────────────────

# --- Order Service Task Role ---
resource "aws_iam_role" "order_service_task" {
  name = "${var.project_name}-order-service-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "order_service_policy" {
  name = "order-service-policy"
  role = aws_iam_role.order_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = [aws_sns_topic.order_created.arn]
    }]
  })
}

# --- Payment Service Task Role ---
resource "aws_iam_role" "payment_service_task" {
  name = "${var.project_name}-payment-service-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "payment_service_policy" {
  name = "payment-service-policy"
  role = aws_iam_role.payment_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [aws_sqs_queue.order_created.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.payment_completed.arn]
      }
    ]
  })
}

# --- Notification Service Task Role ---
resource "aws_iam_role" "notification_service_task" {
  name = "${var.project_name}-notification-service-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "notification_service_policy" {
  name = "notification-service-policy"
  role = aws_iam_role.notification_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [aws_sqs_queue.payment_completed.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.receipts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["*"]
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Security Group for ECS Services
# ─────────────────────────────────────────────
resource "aws_security_group" "ecs_services" {
  name_prefix = "${var.project_name}-ecs-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# ─────────────────────────────────────────────
# ALB
# ─────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
  tags               = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"message\": \"Not Found\"}"
      status_code  = "404"
    }
  }
}

# ─────────────────────────────────────────────
# Order Service — Task Definition + Service
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "order_service" {
  name        = "${var.project_name}-order-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "order_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_service.arn
  }

  condition {
    path_pattern { values = ["/api/v1/orders*"] }
  }
}

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.project_name}-order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.order_service_task.arn

  container_definitions = jsonencode([{
    name  = "order-service"
    image = "${aws_ecr_repository.services["order-service"].repository_url}:latest"

    portMappings = [{ containerPort = 8081, protocol = "tcp" }]

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "ORDER_CREATED_TOPIC_ARN", value = aws_sns_topic.order_created.arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["order-service"].name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = var.tags
}

resource "aws_ecs_service" "order_service" {
  name            = "order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_services.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_service.arn
    container_name   = "order-service"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener_rule.order_service]
  tags       = var.tags
}

# ─────────────────────────────────────────────
# Payment Service — Task Definition + Service
# ─────────────────────────────────────────────
resource "aws_ecs_task_definition" "payment_service" {
  family                   = "${var.project_name}-payment-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.payment_service_task.arn

  container_definitions = jsonencode([{
    name  = "payment-service"
    image = "${aws_ecr_repository.services["payment-service"].repository_url}:latest"

    portMappings = [{ containerPort = 8082, protocol = "tcp" }]

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "PAYMENT_COMPLETED_TOPIC_ARN", value = aws_sns_topic.payment_completed.arn },
      { name = "ORDER_CREATED_QUEUE_NAME", value = aws_sqs_queue.order_created.name }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["payment-service"].name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = var.tags
}

resource "aws_ecs_service" "payment_service" {
  name            = "payment-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payment_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_services.id]
  }

  tags = var.tags
}

# ─────────────────────────────────────────────
# Notification Service — Task Definition + Service
# ─────────────────────────────────────────────
resource "aws_ecs_task_definition" "notification_service" {
  family                   = "${var.project_name}-notification-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.notification_service_task.arn

  container_definitions = jsonencode([{
    name  = "notification-service"
    image = "${aws_ecr_repository.services["notification-service"].repository_url}:latest"

    portMappings = [{ containerPort = 8083, protocol = "tcp" }]

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "PAYMENT_COMPLETED_QUEUE_NAME", value = aws_sqs_queue.payment_completed.name },
      { name = "RECEIPTS_BUCKET_NAME", value = aws_s3_bucket.receipts.id },
      { name = "SES_FROM_EMAIL", value = var.ses_from_email }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services["notification-service"].name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = var.tags
}

resource "aws_ecs_service" "notification_service" {
  name            = "notification-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.notification_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_services.id]
  }

  tags = var.tags
}
