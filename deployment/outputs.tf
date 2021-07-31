output "aws_ecr_repo_url" {
  description = "Repo URL" 
  value = aws_ecr_repository.freqtrade_bot.repository_url
}

output "strategies_instance_ips" {
  description = "freqtradeUI of strategies"
  value = tomap({
    for key, value in aws_instance.freqtrade_strategies : key => "http://${value.public_ip}:${var.configs[key].ft_port}"
  })
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.freqtrade_monitoring.public_ip}:3000"
}
