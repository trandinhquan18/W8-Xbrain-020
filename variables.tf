variable "aws_region" {
  description = "AWS region used to deploy all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix used for resource names and tags."
  type        = string
  default     = "xbrain-minikube-alb"
}

variable "vpc_cidr" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance size for Docker and minikube. t3.micro is Free Tier eligible in ap-southeast-1."
  type        = string
  default     = "t3.micro"
}

variable "app_host_port" {
  description = "Fixed EC2 host port reached by the ALB and used as the Kubernetes NodePort."
  type        = number
  default     = 30080

  validation {
    condition     = var.app_host_port >= 30000 && var.app_host_port <= 32767
    error_message = "app_host_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to access the public ALB."
  type        = string
  default     = "0.0.0.0/0"
}

variable "route53_zone_name" {
  description = "Existing public Route53 hosted zone name. Leave empty to skip Route53 and use the ALB DNS name."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "DNS name that should point to the ALB. Leave empty to skip Route53 and use the ALB DNS name."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH to the EC2 host. For better security, pass your public IPv4 with /32."
  type        = string
  default     = "0.0.0.0/0"
}
