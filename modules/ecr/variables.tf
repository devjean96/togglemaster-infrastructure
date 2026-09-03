variable "repository_names" { type = list(string) }
variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}
variable "max_untagged_images" {
  type    = number
  default = 5
}
variable "force_delete" {
  description = "Permite remover repositorios que ainda contenham imagens. Use apenas em ambientes descartaveis."
  type        = bool
  default     = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
