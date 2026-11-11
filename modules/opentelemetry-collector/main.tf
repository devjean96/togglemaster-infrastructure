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
    prometheus = {
      enabled      = var.enable_prometheus_metrics
      otlpEndpoint = var.prometheus_otlp_endpoint
    }
    logs = {
      enabled      = var.enable_loki_logs
      lokiEndpoint = var.loki_otlp_endpoint
      resources    = var.log_collector_resources
    }
    resources = var.resources
  })]
}
