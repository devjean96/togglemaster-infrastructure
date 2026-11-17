variable "role_name" {
  description = "Nome da role assumida pelo EKS Pod Identity."
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes autorizado a assumir a role."
  type        = string
}

variable "service_account" {
  description = "ServiceAccount Kubernetes autorizado a assumir a role."
  type        = string
}

variable "permissions_policy_json" {
  description = "Policy IAM de runtime do workload."
  type        = string
}

variable "tags" {
  description = "Tags aplicadas à role IAM."
  type        = map(string)
  default     = {}
}
