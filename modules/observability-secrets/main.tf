# Segredos da stack de observabilidade instalada via GitOps (Grafana, alertas e
# self-healer). Ficam fora do Git: o ArgoCD so referencia os nomes dos Secrets.
# Senha do Grafana e token do self-healer sao gerados quando nao informados.

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "random_password" "self_healer_token" {
  length  = 48
  special = false
}

locals {
  grafana_admin_password = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_admin.result
  self_healer_token      = var.self_healer_token != "" ? var.self_healer_token : random_password.self_healer_token.result
  labels = {
    "app.kubernetes.io/part-of"    = "togglemaster-observability"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "admin-user"     = "admin"
    "admin-password" = local.grafana_admin_password
  }
}

# Lido pelo Grafana (envFromSecret) e pelo self-healer.
resource "kubernetes_secret_v1" "alerting" {
  metadata {
    name      = "observability-alerting"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    PAGERDUTY_INTEGRATION_KEY = var.pagerduty_integration_key
    DISCORD_WEBHOOK_URL       = var.discord_webhook_url
    SELF_HEALER_TOKEN         = local.self_healer_token
  }
}
