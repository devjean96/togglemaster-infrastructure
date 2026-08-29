output "state_bucket_name" {
  description = "Bucket usado pelo backend S3."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket de state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend" {
  description = "Configuracao do backend do ambiente unico de homologacao."
  value = {
    bucket       = aws_s3_bucket.terraform_state.id
    key          = "togglemaster/homolog/terraform.tfstate"
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}
