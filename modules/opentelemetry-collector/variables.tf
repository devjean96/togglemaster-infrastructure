variable "namespace" {
  description = "Namespace Kubernetes dedicado a observabilidade."
  type        = string
  default     = "observability"
}

variable "image_repository" {
  description = "Imagem oficial da distribuicao contrib do OpenTelemetry Collector."
  type        = string
  default     = "otel/opentelemetry-collector-contrib"
}

variable "image_tag" {
  description = "Versao imutavel do OpenTelemetry Collector."
  type        = string
  default     = "0.164.0"
}

variable "replica_count" {
  description = "Quantidade de replicas do gateway OTLP. Uma replica reduz custo no AWS Academy."
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1
    error_message = "replica_count deve ser pelo menos 1."
  }
}

variable "newrelic_otlp_endpoint" {
  description = "Endpoint OTLP/HTTP regional do New Relic, sem o caminho /v1/traces."
  type        = string
  default     = "https://otlp.nr-data.net"

  validation {
    condition     = can(regex("^https://", var.newrelic_otlp_endpoint))
    error_message = "newrelic_otlp_endpoint deve usar HTTPS."
  }
}

variable "newrelic_license_key" {
  description = "License key de ingestao do New Relic. O valor e sensivel e deve ser fornecido por TF_VAR_newrelic_license_key."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.newrelic_license_key)) >= 32
    error_message = "newrelic_license_key deve possuir pelo menos 32 caracteres."
  }
}

variable "resources" {
  description = "Requests e limits do Collector, ajustados para o AWS Academy."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "256Mi"
    }
  }
}
