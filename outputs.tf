output "app_url" {
  description = "Public URL served through Route53."
  value       = "http://${local.domain_name}"
}

output "domain_name" {
  description = "Route53 DNS name pointing to the ALB."
  value       = local.domain_name
}

output "alb_dns_name" {
  description = "DNS name of the public ALB."
  value       = aws_lb.app.dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance running Docker and minikube."
  value       = aws_instance.minikube_host.id
}


output "ec2_public_ip" {
  description = "Public IP of the EC2 minikube host."
  value       = aws_instance.minikube_host.public_ip
}

output "ssh_command" {
  description = "SSH command for direct access when ssh_public_key_path is set."
  value       = var.ssh_public_key_path == "" ? "SSH disabled. Set ssh_public_key_path and apply again." : "ssh -i ${var.ssh_private_key_path != "" ? var.ssh_private_key_path : trimsuffix(var.ssh_public_key_path, ".pub")} ec2-user@${aws_instance.minikube_host.public_ip}"
}
