output "freqtrade_instance_ips" {
    description = "IPs of instances that are running the strategies"
    value = module.ec2_instances.*.public_ip
}

output "freqtrade_monitoring_instance_ips" {
    description = "IPs of instances that handle monitoring" 
    value = module.nano_instances.*.public_ip
}

# output "alb_dns" {
#    description = "DNS of ALB" 
#    value = aws_lb.application_load_balancer.dns_name
# }