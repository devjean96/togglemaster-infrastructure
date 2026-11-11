output "alerting_secret_name" {
  value = kubernetes_secret_v1.alerting.metadata[0].name
}

output "grafana_admin_password" {
  value     = local.grafana_admin_password
  sensitive = true
}
