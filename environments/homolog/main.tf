locals {
  environment = "homolog"
  name_prefix = "togglemaster-${local.environment}"
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

resource "terraform_data" "academy_guardrail" {
  input = var.academy_mode

  lifecycle {
    precondition {
      condition     = var.academy_mode
      error_message = "Este root foi projetado para AWS Academy; mantenha academy_mode=true."
    }
  }
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

  cluster_name           = "${local.name_prefix}-eks"
  lab_role_arn           = var.lab_role_arn
  subnet_ids             = module.networking.private_subnet_ids
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = var.eks_endpoint_public_access
  public_access_cidrs    = var.eks_public_access_cidrs
  node_instance_types    = var.eks_node_instance_types
  desired_size           = var.eks_desired_size
  min_size               = var.eks_min_size
  max_size               = var.eks_max_size
  tags                   = local.common_tags

  depends_on = [terraform_data.academy_guardrail]
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

  depends_on = [module.eks, module.ingress_nginx]
}
