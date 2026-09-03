resource "helm_release" "this" {
  name             = "togglemaster-workload-secrets"
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 300

  values = [yamlencode({
    auth = {
      databaseUrl = var.auth_database_url
      masterKey   = var.auth_master_key
    }
    flags = {
      databaseUrl = var.flags_database_url
    }
    targeting = {
      databaseUrl = var.targeting_database_url
    }
    evaluation = {
      serviceApiKey = var.evaluation_service_api_key
    }
  })]
}
