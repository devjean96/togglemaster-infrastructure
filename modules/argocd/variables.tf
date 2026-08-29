variable "namespace" {
  type    = string
  default = "argocd"
}
variable "chart_version" {
  description = "Versao do chart Helm argo-cd."
  type        = string
  default     = "7.7.16"
}
variable "service_type" {
  type    = string
  default = "ClusterIP"
}

variable "bootstrap_gitops" {
  description = "Cria a root Application junto com o release Helm do ArgoCD."
  type        = bool
  default     = true
}

variable "gitops_repository_url" {
  description = "Repositorio observado pela root Application do ArgoCD."
  type        = string

  validation {
    condition     = can(regex("^https://", var.gitops_repository_url))
    error_message = "Use uma URL HTTPS para o repositorio GitOps."
  }
}

variable "gitops_target_revision" {
  type    = string
  default = "main"
}

variable "gitops_root_path" {
  type    = string
  default = "argocd"
}
