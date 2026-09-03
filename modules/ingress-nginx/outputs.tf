output "namespace" {
  value = var.namespace
}

output "service_name" {
  value = data.kubernetes_service_v1.controller.metadata[0].name
}

output "load_balancer_hostname" {
  description = "Hostname publico criado pela AWS; pode ficar nulo ate o NLB concluir o provisionamento."
  value       = try(data.kubernetes_service_v1.controller.status[0].load_balancer[0].ingress[0].hostname, null)
}
