output "role_arn" {
  description = "ARN da role associada ao ServiceAccount."
  value       = aws_iam_role.this.arn

  depends_on = [aws_iam_role_policy.runtime]
}
