output "deployment_id" {
  description = "Unique identifier for this deployment"
  value       = local.name_prefix
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "openwebui_url" {
  description = "URL for OpenWebUI interface"
  value       = "http://${aws_instance.app.public_ip}:8080"
}

output "ollama_api_url" {
  description = "URL for Ollama API"
  value       = "http://${aws_instance.app.public_ip}:11434"
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.app.public_ip}"
}

output "tail_deploy_logs" {
  description = "Command to tail deployment logs"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.app.public_ip} 'sudo tail -f /var/log/deploy.log'"
}

output "tail_model_pull_logs" {
  description = "Command to tail model pull logs"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.app.public_ip} 'sudo tail -f /var/log/model-pull.log'"
}

output "cloudwatch_logs_url" {
  description = "URL to CloudWatch Logs in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/${aws_cloudwatch_log_group.app_logs.name}"
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "app_log_stream" {
  description = "CloudWatch Log Stream for application logs"
  value       = aws_cloudwatch_log_stream.app_log_stream.name
}

output "model_pull_stream" {
  description = "CloudWatch Log Stream for model pull logs"
  value       = aws_cloudwatch_log_stream.model_pull_stream.name
}
