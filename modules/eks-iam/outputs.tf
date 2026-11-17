output "cluster_role_arn" {
  description = "ARN da role do control plane do EKS."
  value       = aws_iam_role.cluster.arn

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

output "node_role_arn" {
  description = "ARN da role das instancias do Managed Node Group."
  value       = aws_iam_role.node.arn

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr_pull,
    aws_iam_role_policy_attachment.node_vpc_cni,
  ]
}
