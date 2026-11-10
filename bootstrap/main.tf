// O provider AWS sempre consulta Object Lock ao atualizar aws_s3_bucket, mas
// essa operacao e bloqueada pela SCP do AWS Academy. A criacao idempotente fica
// num bootstrap via AWS CLI; depois disso o bucket e tratado como externo.
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = coalesce(
    var.state_bucket_name,
    "togglemaster-terraform-state-${data.aws_caller_identity.current.account_id}",
  )
}

resource "terraform_data" "state_bucket" {
  triggers_replace = [local.state_bucket_name, var.aws_region]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-state-bucket.sh"

    environment = {
      STATE_BUCKET_NAME   = local.state_bucket_name
      STATE_BUCKET_REGION = var.aws_region
    }
  }
}

data "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  depends_on = [terraform_data.state_bucket]
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# AWS Academy exception: the state remains encrypted with SSE-S3. A customer
# managed KMS key is not provisioned because of lab permissions and cost limits.
#trivy:ignore:AWS-0132:exp:2027-08-29
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state.json
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [data.aws_s3_bucket.terraform_state.arn, "${data.aws_s3_bucket.terraform_state.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
