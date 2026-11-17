variable "cluster_name" { type = string }
variable "cluster_role_arn" {
  description = "ARN da role assumida pelo control plane do Amazon EKS."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+", var.cluster_role_arn))
    error_message = "cluster_role_arn deve ser uma ARN valida de role IAM."
  }
}
variable "node_role_arn" {
  description = "ARN da role assumida pelas instancias do Managed Node Group."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+", var.node_role_arn))
    error_message = "node_role_arn deve ser uma ARN valida de role IAM."
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
    condition     = length(var.public_access_cidrs) > 0
    error_message = "Informe pelo menos um CIDR para acesso ao endpoint do EKS."
  }
}

variable "cluster_admin_principal_arns" {
  description = "IAM principals authorized as cluster administrators through EKS access entries."
  type        = set(string)
  default     = []
}

variable "https_egress_cidrs" {
  description = "CIDRs de destino autorizados para saida HTTPS dos nodes EKS. Endpoints SaaS podem alterar seus IPs, portanto o padrao libera somente TCP/443 para a Internet."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.https_egress_cidrs) > 0 && alltrue([for cidr in var.https_egress_cidrs : can(cidrnetmask(cidr))])
    error_message = "https_egress_cidrs deve conter ao menos um CIDR IPv4 valido."
  }
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}
variable "node_group_name" {
  description = "Nome opcional do managed node group. Quando nulo, usa <cluster_name>-nodes."
  type        = string
  default     = null

  validation {
    condition     = var.node_group_name == null || can(regex("^[0-9A-Za-z][A-Za-z0-9_-]{0,62}$", var.node_group_name))
    error_message = "node_group_name deve ser nulo ou um nome EKS valido com ate 63 caracteres."
  }
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
  default = ["coredns", "kube-proxy", "vpc-cni", "metrics-server", "eks-pod-identity-agent"]
}
variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
