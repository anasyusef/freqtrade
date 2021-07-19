output "strategies_instance_ips" {
  description = "IPs of instances that are running the strategies"
  value = tomap({
    for key, value in module.ec2_instances : key => value.public_ip
  })
}

output "freqtrade_monitoring_instance_ips" {
  description = "IPs of instances that handle monitoring"
  value       = module.nano_instances.*.public_ip
}
