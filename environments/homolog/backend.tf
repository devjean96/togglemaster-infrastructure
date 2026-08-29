terraform {
  backend "s3" {
    key          = "togglemaster/homolog/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

