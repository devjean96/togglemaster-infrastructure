variable "table_name" {
  type    = string
  default = "ToggleMasterAnalytics"
}
variable "point_in_time_recovery_enabled" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}

