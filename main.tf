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

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "freqtrade_vpc"
  cidr   = "10.0.0.0/16"

  azs = [
    "ap-northeast-1a",
    "ap-northeast-1c",
    "ap-northeast-1d"
  ]
  public_subnets = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_security_group" "ec2_instances_sg" {
  vpc_id = module.vpc.vpc_id

  ingress = [
    {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow SSH from anywhere (develop)"
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "TCP"
    security_groups  = []
    self             = false
    to_port          = 22
    },
  #   {
  #     cidr_blocks      = []
  #     description      = "Allow inbound traffic from ALB"
  #     from_port        = 0
  #     ipv6_cidr_blocks = []
  #     prefix_list_ids  = []
  #     protocol         = "all"
  #     security_groups  = ["${aws_security_group.load_balancer_sg.id}"]
  #     self             = false
  #     to_port          = 0
  # }
  ]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow every outbound traffic"
    from_port        = 0
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    protocol         = -1
    security_groups  = []
    self             = false
    to_port          = 0
  }]

  # depends_on = [
  #   aws_security_group.load_balancer_sg
  # ]
}


module "ec2_instances" {
  source         = "terraform-aws-modules/ec2-instance/aws"
  name           = "freqtrade-ec2-cluster"
  instance_count = 3

  ami                    = "ami-0f4146903324aaa5b"
  instance_type          = "t2.micro"
  key_name               = "TokyoKey"
  vpc_security_group_ids = [aws_security_group.ec2_instances_sg.id]
  iam_instance_profile   = "ecsInstanceRole"
  subnet_ids             = module.vpc.public_subnets
  user_data              = <<EOT
  #!/bin/bash
  echo ECS_CLUSTER="${aws_ecs_cluster.freqtrade_cluster.name}" >> /etc/ecs/ecs.config
  EOT

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
  depends_on = [
    aws_ecs_cluster.freqtrade_cluster
  ]
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
resource "aws_ecs_task_definition" "freqtrade_task" {
  for_each = var.configs
  family = "freqtrade_task_${each.key}"
  container_definitions = jsonencode(
    [
      {
        name      = "freqtrade_task_${each.key}"
        image     = "${aws_ecr_repository.freqtrade_bot.repository_url}:latest"
        essential = true
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
          "--config", "/freqtrade/user_data/config.json",
          "--config", each.value,
        ]
        portMappings = [
          {
            hostPort      = 8080,
            containerPort = 8080,
          }
        ],
        healthCheck = {
          interval = 30
          command = [
            "CMD-SHELL",
            "curl -f localhost:8080/api/v1/ping || exit 1"
          ],
          timeout = 15
          startPeriod = 120
          retries = 3
        }
      }
    ]
  )
  requires_compatibilities = ["EC2"]
  memory                   = "800"
  cpu                      = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

}

resource "aws_cloudwatch_log_group" "freqtrade_log_group" {
  name              = "freqtrade_log_group"
  retention_in_days = 7
}
resource "aws_ecs_service" "freqtrade_service" {
  for_each = var.configs
  name                               = "freqtrade_service_${each.key}"
  cluster                            = aws_ecs_cluster.freqtrade_cluster.id
  task_definition                    = aws_ecs_task_definition.freqtrade_task[each.key].arn
  launch_type                        = "EC2"
  desired_count                      = 1
  # health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  # network_configuration {
  #   subnets = module.vpc.public_subnets
  #   security_groups  = ["${aws_security_group.service_sg.id}"]
  # }

  # load_balancer {
  #   target_group_arn = aws_lb_target_group.target_group.arn
  #   container_name   = aws_ecs_task_definition.freqtrade_task[each.key].family
  #   container_port   = 8080
  # }

  # depends_on = [
  #   aws_lb.application_load_balancer
  # ]
}

# resource "aws_security_group" "service_sg" {
#   vpc_id = module.vpc.vpc_id
#   ingress = [{
#     cidr_blocks      = []
#     description      = "Only allow traffic from the load balancer"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "all"
#     security_groups  = ["${aws_security_group.load_balancer_sg.id}"]
#     self             = false
#     to_port          = 0
#   }]

#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow outbund traffic to anywhere"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "all"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
# }
# resource "aws_lb" "application_load_balancer" {
#   name               = "freqtrade-lb"
#   internal           = false
#   load_balancer_type = "application"
#   subnets            = module.vpc.public_subnets
#   security_groups    = ["${aws_security_group.load_balancer_sg.id}"]
# }

# resource "aws_security_group" "load_balancer_sg" {
#   vpc_id = module.vpc.vpc_id
#   ingress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#     from_port        = 8080
#     to_port          = 8080
#     description      = "Allow traffic from anywhere"
#     security_groups  = []
#     prefix_list_ids  = []
#     self             = false
#     protocol         = "tcp"
#   }]

#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#     from_port        = 0
#     to_port          = 0
#     description      = "Allowing traffic from anywhere to any incoming or outcoming ports"
#     protocol         = -1
#     security_groups  = []
#     prefix_list_ids  = []
#     self             = false
#   }]

# }

# resource "aws_lb_target_group_attachment" "tg_attachment" {
#   target_group_arn = aws_lb_target_group.target_group.arn
#   target_id        = module.ec2_instances.id[0]
#   depends_on = [
#     aws_lb_target_group.target_group
#   ]
# }
# resource "aws_lb_target_group" "target_group" {
#   name        = "freqtrade-tg"
#   port        = "8080"
#   protocol    = "HTTP"
#   target_type = "instance"
#   vpc_id      = module.vpc.vpc_id
#   health_check {
#     matcher  = "200"
#     path     = "/api/v1/ping"
#     interval = 60
#     timeout  = 30
#   }
# }

# resource "aws_lb_listener" "listener" {
#   load_balancer_arn = aws_lb.application_load_balancer.arn
#   port              = "8080"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.target_group.arn
#   }
# }



