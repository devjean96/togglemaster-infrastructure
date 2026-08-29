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
  default = null
}
variable "eks_endpoint_public_access" {
  type    = bool
  default = true
}
variable "eks_public_access_cidrs" {
  description = "CIDRs publicos autorizados no endpoint EKS; informe ao menos um /32 da equipe."
  type        = list(string)
  validation {
    condition     = length(var.eks_public_access_cidrs) > 0 && !contains(var.eks_public_access_cidrs, "0.0.0.0/0")
    error_message = "Informe CIDRs restritos; 0.0.0.0/0 nao e permitido."
  }
}
variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "eks_desired_size" {
  type    = number
  default = 1
}
variable "eks_min_size" {
  type    = number
  default = 1
}
variable "eks_max_size" {
  type    = number
  default = 2
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
variable "install_argocd" {
  type    = bool
  default = true
}
variable "argocd_chart_version" {
  type    = string
  default = "7.7.16"
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
