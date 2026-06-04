locals {
  app_name          = "welcome-xbrain"
  cluster_name      = "xbrain-minikube"
  domain_name       = trimsuffix(var.domain_name, ".")
  route53_zone_name = trimsuffix(var.route53_zone_name, ".")
  route53_enabled   = local.domain_name != "" && local.route53_zone_name != ""
  ssh_key_path      = "${path.module}/generated/xbrain-minikube"
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
