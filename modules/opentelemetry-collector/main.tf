resource "helm_release" "this" {
  name             = "opentelemetry-collector"
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600
  wait            = true

  values = [yamlencode({
    image = {
      repository = var.image_repository
      tag        = var.image_tag
    }
    replicaCount = var.replica_count
    newRelic = {
      endpoint   = var.newrelic_otlp_endpoint
      licenseKey = var.newrelic_license_key
    }
    resources = var.resources
  })]
}
