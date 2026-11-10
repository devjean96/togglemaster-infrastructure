variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "academy_mode" {
  type    = bool
  default = true
}
variable "lab_role_arn" {
  description = "ARN da LabRole fornecida pelo AWS Academy."
  type        = string
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/LabRole$", var.lab_role_arn))
    error_message = "Informe a ARN da LabRole no formato arn:aws:iam::ACCOUNT_ID:role/LabRole."
  }
}
variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}
variable "enable_nat_gateway" {
  description = "Necessario para nodes privados acessarem ECR/Internet; possui custo por hora."
  type        = bool
  default     = true
}
variable "kubernetes_version" {
  type    = string
  default = "1.36"
}
variable "eks_endpoint_public_access" {
  type    = bool
  default = true
}
variable "eks_public_access_cidrs" {
  description = "CIDRs autorizados no endpoint publico do EKS. No GitHub-hosted runner do AWS Academy, 0.0.0.0/0 e aceito como bypass documentado."
  type        = list(string)
  validation {
    condition     = length(var.eks_public_access_cidrs) > 0
    error_message = "Informe pelo menos um CIDR para acesso ao endpoint do EKS."
  }
}
variable "eks_https_egress_cidrs" {
  description = "CIDRs autorizados como destino da saida TCP/443 dos nodes EKS."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.eks_https_egress_cidrs) > 0 && alltrue([for cidr in var.eks_https_egress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Informe ao menos um CIDR IPv4 valido para a saida HTTPS."
  }
}
variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}
variable "eks_desired_size" {
  type    = number
  default = 3
}
variable "eks_min_size" {
  type    = number
  default = 3
}
variable "eks_max_size" {
  type    = number
  default = 3
}
variable "db_username" {
  type    = string
  default = "togglemaster"
}
variable "auth_db_password" {
  type      = string
  sensitive = true
}
variable "flags_db_password" {
  type      = string
  sensitive = true
}
variable "targeting_db_password" {
  type      = string
  sensitive = true
}
variable "auth_master_key" {
  description = "Chave usada para proteger operacoes internas do auth-service."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.auth_master_key) >= 32
    error_message = "auth_master_key deve possuir pelo menos 32 caracteres."
  }
}
variable "evaluation_service_api_key" {
  description = "Chave de autenticacao interna do evaluation-service."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.evaluation_service_api_key) >= 32
    error_message = "evaluation_service_api_key deve possuir pelo menos 32 caracteres."
  }
}
variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "rds_allocated_storage" {
  type    = number
  default = 20
}
variable "rds_max_allocated_storage" {
  type    = number
  default = 50
}
variable "rds_backup_retention_period" {
  type    = number
  default = 1
}
variable "rds_deletion_protection" {
  type    = bool
  default = false
}
variable "rds_multi_az" {
  type    = bool
  default = false
}
variable "rds_performance_insights_enabled" {
  type    = bool
  default = false
}
variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}
variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}
variable "redis_num_cache_clusters" {
  type    = number
  default = 1
}
variable "dynamodb_point_in_time_recovery" {
  type    = bool
  default = false
}
variable "install_opentelemetry_collector" {
  description = "Instala o OpenTelemetry Collector gateway no EKS."
  type        = bool
  default     = true
}
variable "opentelemetry_namespace" {
  type    = string
  default = "observability"
}
variable "opentelemetry_collector_image_tag" {
  description = "Versao da imagem otel/opentelemetry-collector-contrib."
  type        = string
  default     = "0.164.0"
}
variable "opentelemetry_collector_replicas" {
  description = "Uma replica e suficiente para o ambiente de homologacao no AWS Academy."
  type        = number
  default     = 1
}
variable "newrelic_otlp_endpoint" {
  description = "Endpoint OTLP/HTTP do New Relic correspondente a regiao da conta."
  type        = string
  default     = "https://otlp.nr-data.net"
}
variable "newrelic_license_key" {
  description = "License key de ingestao do New Relic. Forneca por TF_VAR_newrelic_license_key."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.newrelic_license_key)) >= 32
    error_message = "newrelic_license_key deve possuir pelo menos 32 caracteres."
  }
}
variable "install_argocd" {
  type    = bool
  default = true
}
variable "install_ingress_nginx" {
  description = "Instala o ingress-nginx e cria um Network Load Balancer publico."
  type        = bool
  default     = true
}
variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.15.1"
}
variable "ingress_load_balancer_source_ranges" {
  description = "CIDRs autorizados a acessar os microservicos pelo Load Balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
variable "argocd_chart_version" {
  type    = string
  default = "10.4.1"
}
variable "argocd_bootstrap_gitops" {
  type    = bool
  default = true
}
variable "gitops_repository_url" {
  type    = string
  default = "https://github.com/devjean96/togglemaster-gitops.git"
}
variable "gitops_target_revision" {
  type    = string
  default = "main"
}
variable "tags" {
  type    = map(string)
  default = {}
}
