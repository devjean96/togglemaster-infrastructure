data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    sid     = "AllowEksControlPlane"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name                  = "${var.name_prefix}-eks-cluster-role"
  description           = "Role assumida pelo control plane do Amazon EKS."
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role.json
  force_detach_policies = true
  tags                  = merge(var.tags, { Name = "${var.name_prefix}-eks-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    sid     = "AllowEc2Nodes"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                  = "${var.name_prefix}-eks-node-role"
  description           = "Role das instancias EC2 do Managed Node Group do Amazon EKS."
  assume_role_policy    = data.aws_iam_policy_document.node_assume_role.json
  force_detach_policies = true
  tags                  = merge(var.tags, { Name = "${var.name_prefix}-eks-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_pull" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# Mantida na role dos nodes para que o VPC CNI consiga inicializar antes dos
# demais add-ons. Para este ambiente temporario, isso evita uma dependencia
# circular de bootstrap entre o CNI e o EKS Pod Identity Agent.
resource "aws_iam_role_policy_attachment" "node_vpc_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
