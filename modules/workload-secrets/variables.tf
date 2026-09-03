variable "namespace" {
  description = "Namespace dos workloads e dos Secrets."
  type        = string
}

variable "auth_database_url" {
  type      = string
  sensitive = true
}

variable "auth_master_key" {
  type      = string
  sensitive = true
}

variable "flags_database_url" {
  type      = string
  sensitive = true
}

variable "targeting_database_url" {
  type      = string
  sensitive = true
}

variable "evaluation_service_api_key" {
  type      = string
  sensitive = true
}
