output "rackula_url" {
  value = "http://${module.my_server.public_ip}:8080"
}

output "ssm_command" {
  value = "aws ssm start-session --target ${module.my_server.id} --region ${data.aws_region.current.name}"
}
