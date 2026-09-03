output "eks_cluster_name" { value = module.eks.cluster_name }
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "rds_endpoints" {
  value     = module.rds.endpoints
  sensitive = true
}
output "redis_endpoint" { value = module.elasticache.primary_endpoint }
output "dynamodb_table_name" { value = module.dynamodb.table_name }
output "sqs_queue_url" { value = module.sqs.queue_url }
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "auth_ecr_repository_url" {
  value = module.ecr.repository_urls["${local.name_prefix}/auth-service"]
}
output "argocd_namespace" { value = try(module.argocd[0].namespace, null) }
output "argocd_root_application" {
  value = try(module.argocd[0].root_application_name, null)
}
output "workload_secrets_release" {
  value = module.workload_secrets.release_name
}
output "ingress_nginx_namespace" {
  value = try(module.ingress_nginx[0].namespace, null)
}
output "ingress_load_balancer_hostname" {
  description = "Hostname publico para acessar os microservicos pelos prefixos /auth, /flags, /targeting, /evaluate e /analytics."
  value       = try(module.ingress_nginx[0].load_balancer_hostname, null)
}
output "auth_service_external_url" {
  value = try("http://${module.ingress_nginx[0].load_balancer_hostname}/auth", null)
}
output "microservice_external_urls" {
  description = "URLs publicas dos microservicos expostos pelo Ingress NGINX."
  value = try({
    auth       = "http://${module.ingress_nginx[0].load_balancer_hostname}/auth"
    flags      = "http://${module.ingress_nginx[0].load_balancer_hostname}/flags"
    targeting  = "http://${module.ingress_nginx[0].load_balancer_hostname}/targeting"
    evaluation = "http://${module.ingress_nginx[0].load_balancer_hostname}/evaluate"
    analytics  = "http://${module.ingress_nginx[0].load_balancer_hostname}/analytics"
  }, null)
}
