locals {
  app_name          = "welcome-xbrain"
  cluster_name      = "xbrain-minikube"
  domain_name       = trimsuffix(var.domain_name, ".")
  route53_zone_name = trimsuffix(var.route53_zone_name, ".")
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
