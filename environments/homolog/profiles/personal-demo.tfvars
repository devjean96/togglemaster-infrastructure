deployment_profile = "personal"
aws_region         = "us-east-2"
availability_zones = ["us-east-2a", "us-east-2b"]

# Mantem a mesma capacidade e todos os componentes do ambiente Academy.
eks_node_instance_types = ["t3.large"]
eks_desired_size        = 3
eks_min_size            = 3
eks_max_size            = 3
enable_nat_gateway      = true
install_ingress_nginx   = true
install_loki            = true

# A demonstracao usa as branches temporarias e o overlay dedicado.
gitops_target_revision = "feat/aws-temporary-demo"
gitops_root_path       = "argocd-overlays/personal-demo"
