variable "cluster_name" { type = string }
variable "lab_role_arn" {
  description = "ARN da LabRole existente no AWS Academy. Nenhuma role IAM e criada por este modulo."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+", var.lab_role_arn))
    error_message = "lab_role_arn deve ser uma ARN valida de role IAM."
  }
}
variable "subnet_ids" { type = list(string) }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "public_access_cidrs" {
  description = "CIDRs autorizados a acessar o endpoint publico do EKS."
  type        = list(string)

  validation {
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "O endpoint do EKS nao pode ser exposto para 0.0.0.0/0."
  }
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "node_disk_size" {
  type    = number
  default = 20
}
variable "desired_size" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "cluster_addons" {
  type    = list(string)
  default = ["coredns", "kube-proxy", "vpc-cni"]
}
variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
