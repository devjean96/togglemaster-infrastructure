data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowEksAuthToAssumeRoleForPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = [var.namespace]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [var.service_account]
    }
  }
}

resource "aws_iam_role" "this" {
  name                  = var.role_name
  description           = "Role do EKS Pod Identity para ${var.namespace}/${var.service_account}."
  assume_role_policy    = data.aws_iam_policy_document.assume_role.json
  force_detach_policies = true
  tags                  = merge(var.tags, { Name = var.role_name })
}

resource "aws_iam_role_policy" "runtime" {
  name   = "${var.role_name}-runtime"
  role   = aws_iam_role.this.id
  policy = var.permissions_policy_json
}
