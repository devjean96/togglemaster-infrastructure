variable "aws_region" {
  description = "Regiao AWS onde o bucket de state sera criado."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nome globalmente unico do bucket S3 de state."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "O nome do bucket deve ter entre 3 e 63 caracteres."
  }
}

variable "tags" {
  description = "Tags comuns do bootstrap."
  type        = map(string)
  default = {
    Project   = "ToggleMaster"
    ManagedBy = "Terraform"
    Layer     = "bootstrap"
  }
}

