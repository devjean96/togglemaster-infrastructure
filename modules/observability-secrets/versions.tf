terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
