variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "subnet_ids" { type = list(string) }
variable "databases" {
  type = map(object({
    database_name = string
    username      = string
    password      = string
  }))
  sensitive = true
}
variable "engine_version" {
  type    = string
  default = "16"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "max_allocated_storage" {
  type    = number
  default = 50
}
variable "backup_retention_period" {
  type    = number
  default = 7
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "performance_insights_enabled" {
  type    = bool
  default = false
}
variable "deletion_protection" { type = bool }
variable "skip_final_snapshot" { type = bool }
variable "apply_immediately" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
