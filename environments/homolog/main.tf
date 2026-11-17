locals {
  environment        = "homolog"
  name_prefix        = "togglemaster-${local.environment}"
  workload_namespace = local.name_prefix
  common_tags = merge(var.tags, {
    Project     = "ToggleMaster"
    Environment = local.environment
    ManagedBy   = "Terraform"
  })

  databases = {
    auth = {
      database_name = "auth_db"
      username      = var.db_username
      password      = var.auth_db_password
    }
    flags = {
      database_name = "flags_db"
      username      = var.db_username
      password      = var.flags_db_password
    }
    targeting = {
      database_name = "targeting_db"
      username      = var.db_username
      password      = var.targeting_db_password
    }
  }
}

resource "terraform_data" "profile_guardrail" {
  input = var.deployment_profile

  lifecycle {
    precondition {
      condition     = var.deployment_profile != "academy" || var.lab_role_arn != null
      error_message = "O perfil academy exige lab_role_arn."
    }

    precondition {
      condition     = var.deployment_profile != "personal" || var.github_bootstrap_principal_arn != null
      error_message = "O perfil personal exige github_bootstrap_principal_arn."
    }
  }
}

module "eks_iam" {
  count  = var.deployment_profile == "personal" ? 1 : 0
  source = "../../modules/eks-iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

locals {
  eks_cluster_role_arn = var.deployment_profile == "academy" ? var.lab_role_arn : module.eks_iam[0].cluster_role_arn
  eks_node_role_arn    = var.deployment_profile == "academy" ? var.lab_role_arn : module.eks_iam[0].node_role_arn
}

module "networking" {
  source = "../../modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  tags                 = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                 = "${local.name_prefix}-eks"
  cluster_role_arn             = local.eks_cluster_role_arn
  node_role_arn                = local.eks_node_role_arn
  subnet_ids                   = module.networking.private_subnet_ids
  kubernetes_version           = var.kubernetes_version
  endpoint_public_access       = var.eks_endpoint_public_access
  public_access_cidrs          = var.eks_public_access_cidrs
  cluster_admin_principal_arns = var.eks_cluster_admin_principal_arns
  https_egress_cidrs           = var.eks_https_egress_cidrs
  node_instance_types          = var.eks_node_instance_types
  node_group_name              = var.eks_node_group_name
  desired_size                 = var.eks_desired_size
  min_size                     = var.eks_min_size
  max_size                     = var.eks_max_size
  tags                         = local.common_tags

  depends_on = [terraform_data.profile_guardrail, module.eks_iam]
}

module "observability_namespace" {
  source = "../../modules/observability-namespace"

  namespace  = var.opentelemetry_namespace
  depends_on = [module.eks]
}

module "loki" {
  count  = var.install_loki ? 1 : 0
  source = "../../modules/loki"

  namespace        = module.observability_namespace.namespace
  chart_version    = var.loki_chart_version
  storage_size     = var.loki_storage_size
  retention_period = var.loki_retention_period

  depends_on = [module.eks]
}

module "opentelemetry_collector" {
  count  = var.install_opentelemetry_collector ? 1 : 0
  source = "../../modules/opentelemetry-collector"

  namespace              = module.observability_namespace.namespace
  image_tag              = var.opentelemetry_collector_image_tag
  replica_count          = var.opentelemetry_collector_replicas
  newrelic_otlp_endpoint = var.newrelic_otlp_endpoint
  newrelic_license_key   = var.newrelic_license_key
  enable_loki_logs       = var.install_loki
  # Fase 4: metricas OTLP e RED -> Prometheus (ArgoCD/namespace observability)
  enable_prometheus_metrics = var.enable_prometheus_metrics
  loki_otlp_endpoint        = try(module.loki[0].otlp_endpoint, "")

  depends_on = [module.eks, module.loki]
}

# Fase 4: segredos do Grafana/alertas (a stack em si e instalada pelo ArgoCD).
module "observability_secrets" {
  count  = var.install_observability_secrets ? 1 : 0
  source = "../../modules/observability-secrets"

  namespace                 = module.observability_namespace.namespace
  grafana_admin_password    = var.grafana_admin_password
  pagerduty_integration_key = var.pagerduty_integration_key
  discord_webhook_url       = var.discord_webhook_url
  self_healer_token         = var.self_healer_token
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                  = local.name_prefix
  vpc_id                       = module.networking.vpc_id
  vpc_cidr                     = module.networking.vpc_cidr
  subnet_ids                   = module.networking.private_subnet_ids
  databases                    = local.databases
  instance_class               = var.rds_instance_class
  allocated_storage            = var.rds_allocated_storage
  max_allocated_storage        = var.rds_max_allocated_storage
  backup_retention_period      = var.rds_backup_retention_period
  multi_az                     = var.rds_multi_az
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot
  performance_insights_enabled = var.rds_performance_insights_enabled
  tags                         = local.common_tags
}

module "workload_secrets" {
  source = "../../modules/workload-secrets"

  namespace = local.name_prefix

  auth_database_url = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=require",
    urlencode(var.db_username),
    urlencode(var.auth_db_password),
    module.rds.endpoints["auth"],
    module.rds.ports["auth"],
    module.rds.database_names["auth"]
  )
  auth_master_key = var.auth_master_key

  # A mesma chave consumida pelo evaluation-service e registrada pelo
  # auth-service no bootstrap. O valor nunca e persistido no Git.
  auth_evaluation_service_api_key = var.evaluation_service_api_key

  flags_database_url = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=require",
    urlencode(var.db_username),
    urlencode(var.flags_db_password),
    module.rds.endpoints["flags"],
    module.rds.ports["flags"],
    module.rds.database_names["flags"]
  )

  targeting_database_url = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=require",
    urlencode(var.db_username),
    urlencode(var.targeting_db_password),
    module.rds.endpoints["targeting"],
    module.rds.ports["targeting"],
    module.rds.database_names["targeting"]
  )

  evaluation_service_api_key = var.evaluation_service_api_key

  depends_on = [module.eks]
}

module "elasticache" {
  source = "../../modules/elasticache"

  name_prefix        = local.name_prefix
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = module.networking.vpc_cidr
  subnet_ids         = module.networking.private_subnet_ids
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_num_cache_clusters
  tags               = local.common_tags
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name                     = "ToggleMasterAnalytics-${local.environment}"
  point_in_time_recovery_enabled = var.dynamodb_point_in_time_recovery
  tags                           = local.common_tags
}

module "sqs" {
  source = "../../modules/sqs"

  queue_name = "${local.name_prefix}-evaluation-events"
  tags       = local.common_tags
}

data "aws_iam_policy_document" "evaluation_runtime" {
  statement {
    sid       = "PublishEvaluationEvents"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs.queue_arn]
  }
}

data "aws_iam_policy_document" "analytics_runtime" {
  statement {
    sid    = "ConsumeEvaluationEvents"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
    ]
    resources = [module.sqs.queue_arn]
  }

  # Baseline gerada pelo IAM Policy Autopilot para boto3 PutItem.
  statement {
    sid    = "StoreAnalyticsEvents"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:WriteDataForReplication",
    ]
    resources = [module.dynamodb.table_arn]
  }
}

module "evaluation_pod_identity" {
  count  = var.deployment_profile == "personal" ? 1 : 0
  source = "../../modules/pod-identity-role"

  role_name               = "${local.name_prefix}-evaluation-pod"
  namespace               = local.workload_namespace
  service_account         = "evaluation-service"
  permissions_policy_json = data.aws_iam_policy_document.evaluation_runtime.json
  tags                    = local.common_tags
}

module "analytics_pod_identity" {
  count  = var.deployment_profile == "personal" ? 1 : 0
  source = "../../modules/pod-identity-role"

  role_name               = "${local.name_prefix}-analytics-pod"
  namespace               = local.workload_namespace
  service_account         = "analytics-service"
  permissions_policy_json = data.aws_iam_policy_document.analytics_runtime.json
  tags                    = local.common_tags
}

resource "aws_eks_pod_identity_association" "evaluation" {
  count = var.deployment_profile == "personal" ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = local.workload_namespace
  service_account = "evaluation-service"
  role_arn        = module.evaluation_pod_identity[0].role_arn

  depends_on = [module.eks]
}

resource "aws_eks_pod_identity_association" "analytics" {
  count = var.deployment_profile == "personal" ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = local.workload_namespace
  service_account = "analytics-service"
  role_arn        = module.analytics_pod_identity[0].role_arn

  depends_on = [module.eks]
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "${local.name_prefix}/auth-service",
    "${local.name_prefix}/flag-service",
    "${local.name_prefix}/targeting-service",
    "${local.name_prefix}/evaluation-service",
    "${local.name_prefix}/analytics-service"
  ]
  force_delete = true
  tags         = local.common_tags
}

data "aws_iam_policy_document" "service_deploy_assume_role" {
  count = var.deployment_profile == "personal" ? 1 : 0

  statement {
    sid     = "AllowGitHubBootstrapUser"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.github_bootstrap_principal_arn]
    }
  }
}

resource "aws_iam_role" "service_deploy" {
  count = var.deployment_profile == "personal" ? 1 : 0

  name                 = "ToggleMasterServiceDeployRole"
  assume_role_policy   = data.aws_iam_policy_document.service_deploy_assume_role[0].json
  max_session_duration = 3600
  tags                 = local.common_tags
}

data "aws_iam_policy_document" "service_deploy" {
  count = var.deployment_profile == "personal" ? 1 : 0

  statement {
    sid       = "AuthenticateToEcr"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishServiceImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = values(module.ecr.repository_arns)
  }
}

resource "aws_iam_role_policy" "service_deploy" {
  count = var.deployment_profile == "personal" ? 1 : 0

  name   = "ToggleMasterServiceImagePublish"
  role   = aws_iam_role.service_deploy[0].id
  policy = data.aws_iam_policy_document.service_deploy[0].json
}

module "ingress_nginx" {
  count  = var.install_ingress_nginx ? 1 : 0
  source = "../../modules/ingress-nginx"

  chart_version               = var.ingress_nginx_chart_version
  load_balancer_source_ranges = var.ingress_load_balancer_source_ranges

  depends_on = [module.eks]
}

module "argocd" {
  count  = var.install_argocd ? 1 : 0
  source = "../../modules/argocd"

  chart_version          = var.argocd_chart_version
  bootstrap_gitops       = var.argocd_bootstrap_gitops
  gitops_repository_url  = var.gitops_repository_url
  gitops_target_revision = var.gitops_target_revision
  gitops_root_path       = var.gitops_root_path

  depends_on = [module.eks, module.ingress_nginx]
}
