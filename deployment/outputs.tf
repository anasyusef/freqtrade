output "aws_ecr_repo_url" {
  description = "Repo URL" 
  value = aws_ecr_repository.freqtrade_bot.repository_url
}

output "strategies_instance_ips" {
  description = "freqtradeUI of strategies"
  value = tomap({
    for key, value in module.ec2_instances : key => "http://${value.public_ip[0]}:${var.configs[key].ft_port}"
  })
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${module.nano_instances.public_ip[0]}:3000"
}
