terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "freqtrade"
    workspaces {
      name = "freqtrade"
    }
  }

}

provider "aws" {
  region = var.region
}

resource "aws_ecr_repository" "freqtrade_bot" {
  name = "freqtrade_bot"
}

resource "aws_ecs_cluster" "freqtrade_cluster" {
  name = "freqtrade_cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# data "aws_ecr_image" "freqtrade_bot" {
#   repository_name = aws_ecr_repository.freqtrade_bot.name
# }

resource "aws_ecs_task_definition" "freqtrade_task" {
  family = "freqtrade_task"
  container_definitions = jsonencode(
    [
      {
        name      = "freqtrade_task"
        # image     = "${aws_ecr_repository.freqtrade_bot.repository_url}:latest@${data.aws_ecr_image.freqtrade_bot.id}"
        image     = "${aws_ecr_repository.freqtrade_bot.repository_url}:latest"
        essential = true
        memory    = 1024
        cpu       = 512
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.freqtrade_log_group.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "ecs"
          }
        }
        command = [
          "trade",
          "--logfile", "/freqtrade/user_data/logs/freqtrade.log",
          "--config", "/freqtrade/user_data/base-config.json",
          "--config", "/freqtrade/user_data/config-prod.json",
          "--strategy", "ProtectedZeus"
        ]
        portMappings = [
          {
            hostPort      = 8080,
            containerPort = 8080,
          }
        ]
      }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

}

resource "aws_cloudwatch_log_group" "freqtrade_log_group" {
  name              = "freqtrade_log_group"
  retention_in_days = 7
}
resource "aws_ecs_service" "freqtrade_service" {
  name                              = "freqtrade_service"
  cluster                           = aws_ecs_cluster.freqtrade_cluster.id
  task_definition                   = aws_ecs_task_definition.freqtrade_task.arn
  launch_type                       = "FARGATE"
  desired_count                     = 1
  health_check_grace_period_seconds = 120
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent = 100

  network_configuration {
    subnets = [
      "${aws_default_subnet.default_subnet_a.id}",
      "${aws_default_subnet.default_subnet_b.id}",
      "${aws_default_subnet.default_subnet_c.id}"
    ]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.service_sg.id}"]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = aws_ecs_task_definition.freqtrade_task.family
    container_port   = 8080
  }
}

resource "aws_security_group" "service_sg" {

  ingress = [{
    cidr_blocks      = []
    description      = "Only allow traffic from the load balancer"
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = ["${aws_security_group.load_balancer_sg.id}"]
    self             = false
    to_port          = 0
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow outbund traffic to anywhere"
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "${var.region}a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "${var.region}d"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "${var.region}c"
}

resource "aws_alb" "application_load_balancer" {
  name               = "freqtrade-lb"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_sg.id}"]
}

resource "aws_security_group" "load_balancer_sg" {
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    from_port        = 8080
    to_port          = 8080
    description      = "Allow traffic from anywhere"
    security_groups  = []
    prefix_list_ids  = []
    self             = false
    protocol         = "tcp"
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    from_port        = 0
    to_port          = 0
    description      = "Allowing traffic from anywhere to any incoming or outcoming ports"
    protocol         = -1
    security_groups  = []
    prefix_list_ids  = []
    self             = false
  }]

}
resource "aws_lb_target_group" "target_group" {
  name        = "freqtrade-tg"
  port        = "8080"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
  health_check {
    matcher  = "200"
    path     = "/api/v1/ping"
    interval = 60
    timeout  = 30
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}



