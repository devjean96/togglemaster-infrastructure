variable "namespace" {
  description = "Namespace Kubernetes compartilhado pelos componentes de observabilidade."
  type        = string
  default     = "observability"
}

variable "chart_repository" {
  description = "Repositorio comunitario oficial do chart OSS do Loki."
  type        = string
  default     = "https://grafana-community.github.io/helm-charts"
}

variable "chart_version" {
  description = "Versao fixa do chart Helm do Loki."
  type        = string
  default     = "21.1.0"
}

variable "storage_size" {
  description = "Limite do volume local temporario do Loki monolitico."
  type        = string
  default     = "20Gi"

  validation {
    condition     = can(regex("^[1-9][0-9]*Gi$", var.storage_size))
    error_message = "storage_size deve ser informado em Gi, por exemplo 20Gi."
  }
}

variable "retention_period" {
  description = "Periodo de retencao dos logs no Loki."
  type        = string
  default     = "168h"

  validation {
    condition     = can(regex("^[1-9][0-9]*h$", var.retention_period))
    error_message = "retention_period deve ser informado em horas, por exemplo 168h."
  }
}

variable "resources" {
  description = "Requests e limits do Loki monolitico."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "gateway_resources" {
  description = "Requests e limits do gateway interno do Loki."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "128Mi"
    }
  }
}
