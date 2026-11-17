variable "name_prefix" {
  description = "Prefixo usado nos nomes das roles do EKS."
  type        = string
}

variable "tags" {
  description = "Tags aplicadas às roles IAM."
  type        = map(string)
  default     = {}
}
