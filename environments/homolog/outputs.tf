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
