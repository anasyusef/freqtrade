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
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_task_definition" "freqtrade_task" {
  family = "freqtrade_task"
  container_definitions = jsonencode(
    [
      {
        name      = "freqtrade_task"
        image     = "${aws_ecr_repository.freqtrade_bot.repository_url}"
        essential = true
        memory    = 512
        cpu       = 256
        portMappings = [
          {
            containerPort = 8080,
            hostPort      = 8080
          }
        ]
      }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "freqtrade_service" {
  name            = "freqtrade_service"
  cluster         = aws_ecs_cluster.freqtrade_cluster.id
  task_definition = aws_ecs_task_definition.freqtrade_task.arn
  launch_type     = "FARGATE"
  desired_count   = 3

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
  }
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



