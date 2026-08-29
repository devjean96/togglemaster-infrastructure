variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "subnet_ids" { type = list(string) }
variable "engine_version" {
  type    = string
  default = "7.1"
}
variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}
variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}
variable "num_cache_clusters" {
  type    = number
  default = 1
}
variable "transit_encryption_enabled" {
  type    = bool
  default = true
}
variable "snapshot_retention_limit" {
  type    = number
  default = 1
}
variable "apply_immediately" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
