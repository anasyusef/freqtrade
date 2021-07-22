terraform {
  backend "s3" {
    bucket = "terraform-store-state-bucket"
    key    = "terraform-state.tfstate"
    region = "eu-west-2"
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
  public_subnets       = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_security_group" "freqtrade_frontend_sg" {
  vpc_id = module.vpc.vpc_id
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow traffic to freqtrade UI"
      from_port        = 8080
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "TCP"
      security_groups  = []
      self             = true
      to_port          = 8080
    }
  ]
}
resource "aws_security_group" "ec2_instances_sg" {
  vpc_id = module.vpc.vpc_id
  ingress = [
    # {
    #   cidr_blocks      = ["0.0.0.0/0"]
    #   description      = "Allow SSH from anywhere (develop)"
    #   from_port        = 22
    #   ipv6_cidr_blocks = []
    #   prefix_list_ids  = []
    #   protocol         = "TCP"
    #   security_groups  = []
    #   self             = false
    #   to_port          = 22
    # },
    {
      cidr_blocks      = []
      description      = "Allow traffic from within SG"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "all"
      security_groups  = []
      self             = true
      to_port          = 0
    }
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
}

resource "aws_security_group" "monitoring_sg" {
  vpc_id = module.vpc.vpc_id
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow traffic to Grafana"
    from_port        = 3000
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "TCP"
    security_groups  = []
    self             = false
    to_port          = 3000
    },
    # {
    #   cidr_blocks      = ["31.52.154.41/32"]
    #   description      = "Allow traffic to Prometheus (develop)"
    #   from_port        = 9090
    #   ipv6_cidr_blocks = []
    #   prefix_list_ids  = []
    #   protocol         = "TCP"
    #   security_groups  = []
    #   self             = false
    #   to_port          = 9090
    # },
  ]
}


module "ec2_instances" {
  for_each       = var.configs
  source         = "terraform-aws-modules/ec2-instance/aws"
  name           = "freqtrade-ec2-cluster-${each.key}"
  instance_count = 1

  ami                    = "ami-0f4146903324aaa5b"
  instance_type          = "t2.micro"
  key_name               = "TokyoKey"
  vpc_security_group_ids = [aws_security_group.ec2_instances_sg.id, aws_security_group.freqtrade_frontend_sg.id]
  iam_instance_profile   = "ecsInstanceRole"
  subnet_ids             = module.vpc.public_subnets
  user_data              = <<EOT
  #!/bin/bash
  echo ECS_CLUSTER="${aws_ecs_cluster.freqtrade_cluster.name}" >> /etc/ecs/ecs.config
  EOT

  tags = {
    Terraform = "true"
    Strategy  = each.key
  }
  depends_on = [
    aws_ecs_cluster.freqtrade_cluster
  ]
}

module "nano_instances" {
  source         = "terraform-aws-modules/ec2-instance/aws"
  name           = "freqtrade-ec2-cluster"
  instance_count = 1

  ami                    = "ami-0f4146903324aaa5b"
  instance_type          = "t2.nano"
  key_name               = "TokyoKey"
  vpc_security_group_ids = [aws_security_group.ec2_instances_sg.id, aws_security_group.monitoring_sg.id]
  iam_instance_profile   = "ecsInstanceRole"
  subnet_ids             = module.vpc.public_subnets
  user_data              = <<EOT
  #!/bin/bash
  echo ECS_CLUSTER="${aws_ecs_cluster.freqtrade_cluster.name}" >> /etc/ecs/ecs.config
  EOT

  tags = {
    Terraform = "true"
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
  for_each     = var.configs
  family       = "freqtrade_task_${each.key}"
  network_mode = "bridge"
  placement_constraints {
    type       = "memberOf"
    expression = "ec2InstanceId == ${module.ec2_instances[each.key].id[0]}"
  }
  container_definitions = jsonencode(
    [
      {
        name      = "freqtrade_task_${each.key}"
        image     = "${aws_ecr_repository.freqtrade_bot.repository_url}:latest"
        essential = true
        portMappings = [
          {
            hostPort      = 8080
            containerPort = 8080
          }
        ]
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
          "--config", each.value.config_path,
        ]
        healthCheck = {
          interval = 60
          command = [
            "CMD-SHELL",
            "curl -f localhost:8080/api/v1/ping || exit 1"
          ],
          timeout     = 15
          startPeriod = 120
          retries     = 3
        }
      },
      {
        name      = "ftmetric_${each.key}"
        image     = "ghcr.io/kamontat/ftmetric:v4.2.0"
        essential = true
        portMappings = [
          {
            hostPort      = 8090
            containerPort = 8090
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.freqtrade_log_group.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "ecs"
          }
        }
        environment = [
          {
            name  = "FTH_FREQTRADE__URL"
            value = "http://freqtrade_task_${each.key}:8080"
          },
          {
            name  = "FTH_FREQTRADE__USERNAME"
            value = var.ft_creds[each.key].ft_username
          },
          {
            name  = "FTH_FREQTRADE__PASSWORD"
            value = var.ft_creds[each.key].ft_password
          }
        ]
        dependsOn = [
          {
            containerName = "freqtrade_task_${each.key}"
            condition     = "HEALTHY"
          }
        ]
        healthCheck = {
          interval = 60
          command = [
            "CMD",
            "wget",
            "--no-verbose",
            "--tries=1",
            "--spider",
            "http://localhost:8090/version",
          ],
          timeout     = 15
          startPeriod = 15
          retries     = 3
        }
        links = [
          "freqtrade_task_${each.key}"
        ]
      }
    ]
  )
  requires_compatibilities = ["EC2"]
  memory                   = each.value.memory
  cpu                      = each.value.cpu
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "freqtrade_monitoring" {
  family       = "freqtrade_monitoring"
  network_mode = "bridge"
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.instance-type == t2.nano"
  }
  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "302142484185.dkr.ecr.ap-northeast-1.amazonaws.com/prometheus:latest"
      command = [
        "--config.file",
        "/etc/prometheus/prometheus.yml"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.freqtrade_log_group.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          hostPort      = 9090
          containerPort = 9090
        }
      ]
      healthCheck = {
        interval = 60
        command = [
          "CMD",
          "wget",
          "--no-verbose",
          "--tries=1",
          "--spider",
          "http://localhost:9090/-/healthy",
        ],
        timeout     = 15
        startPeriod = 15
        retries     = 3
      }
      mountPoints = [
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
        }
      ]
    },
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      links = [
        "prometheus"
      ]
      portMappings = [
        {
          hostPort      = 3000
          containerPort = 3000
        }
      ]
      dependsOn = [
        {
          containerName = "prometheus"
          condition     = "HEALTHY"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.freqtrade_log_group.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        interval = 60
        command = [
          "CMD",
          "wget",
          "--no-verbose",
          "--tries=1",
          "--spider",
          "http://localhost:3000/api/health",
        ],
        timeout     = 15
        startPeriod = 15
        retries     = 3
      }
      environment = [
        {
          name  = "GF_SERVER_HTTP_PORT"
          value = "3000"
        },
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = var.grafana_username
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_password
        },
        {
          name  = "GF_FEATURE_TOGGLES_ENABLE"
          value = "ngalert"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "grafana-data"
          containerPath = "/var/lib/grafana"
        }
      ]
    }
  ])
  volume {
    name = "grafana-data"
    docker_volume_configuration {
      scope         = "shared"
      driver        = "local"
      driver_opts   = {}
      labels        = {}
      autoprovision = true
    }
  }

  volume {
    name = "prometheus-data"
    docker_volume_configuration {
      scope         = "shared"
      driver        = "local"
      driver_opts   = {}
      labels        = {}
      autoprovision = true
    }
  }

  requires_compatibilities = ["EC2"]
  memory                   = 300
  cpu                      = 512
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}


resource "aws_cloudwatch_log_group" "freqtrade_log_group" {
  name              = "freqtrade_log_group"
  retention_in_days = 7
}

resource "aws_ecs_service" "freqtrade_monitoring" {
  name                               = "freqtrade_monitoring"
  cluster                            = aws_ecs_cluster.freqtrade_cluster.id
  task_definition                    = aws_ecs_task_definition.freqtrade_monitoring.arn
  launch_type                        = "EC2"
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  force_new_deployment               = false
}
resource "aws_ecs_service" "freqtrade_service" {
  for_each        = var.configs
  name            = "freqtrade_service_${each.key}"
  cluster         = aws_ecs_cluster.freqtrade_cluster.id
  task_definition = aws_ecs_task_definition.freqtrade_task[each.key].arn
  launch_type     = "EC2"
  force_new_deployment               = false
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.freqtrade_sd[each.key].arn
    container_name = "ftmetric_${each.key}"
    container_port = 8090
  }
}

resource "aws_service_discovery_private_dns_namespace" "freqtrade_sd_namespace" {
  name        = "freqtrade"
  description = "Namespace for freqtrade services"
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "freqtrade_sd" {
  for_each = var.configs
  name     = each.key
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.freqtrade_sd_namespace.id
    dns_records {
      ttl  = 60
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}
