variable "namespace" {
  description = "Namespace da stack de observabilidade (o mesmo do OTel Collector)."
  type        = string
  default     = "observability"
}

variable "grafana_admin_password" {
  description = "Senha do admin do Grafana. Vazio = gerada automaticamente (veja o output grafana_admin_password)."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.grafana_admin_password == "" || length(var.grafana_admin_password) >= 12
    error_message = "grafana_admin_password deve possuir pelo menos 12 caracteres."
  }
}

variable "pagerduty_integration_key" {
  description = "Integration key (Events API v2) do PagerDuty. Vazio = integracao desativada."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.pagerduty_integration_key == "" || length(trimspace(var.pagerduty_integration_key)) == 32
    error_message = "pagerduty_integration_key deve ser a integration key de 32 caracteres da Events API v2."
  }
}

variable "discord_webhook_url" {
  description = "Webhook do canal do Discord (ChatOps). Vazio = integracao desativada."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.discord_webhook_url == "" || can(regex("^https://(discord|discordapp)\\.com/api/webhooks/", var.discord_webhook_url))
    error_message = "discord_webhook_url deve ser uma URL de webhook do Discord."
  }
}

variable "self_healer_token" {
  description = "Token entre o Grafana e o self-healer. Vazio = gerado automaticamente."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.self_healer_token == "" || length(var.self_healer_token) >= 32
    error_message = "self_healer_token deve possuir pelo menos 32 caracteres."
  }
}
