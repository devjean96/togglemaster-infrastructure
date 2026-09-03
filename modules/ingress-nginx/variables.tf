variable "chart_version" {
  description = "Versao do chart Helm oficial ingress-nginx."
  type        = string
}

variable "namespace" {
  description = "Namespace onde o ingress-nginx sera instalado."
  type        = string
  default     = "ingress-nginx"
}

variable "load_balancer_source_ranges" {
  description = "CIDRs autorizados a acessar o Load Balancer publico."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.load_balancer_source_ranges) > 0
    error_message = "Informe pelo menos um CIDR para acesso ao Load Balancer."
  }
}
