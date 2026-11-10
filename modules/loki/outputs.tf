output "namespace" {
  value = helm_release.this.namespace
}

output "release_name" {
  value = helm_release.this.name
}

output "gateway_endpoint" {
  description = "Endpoint HTTP interno para consultas ao Loki."
  value       = "http://loki-gateway.${helm_release.this.namespace}.svc.cluster.local"
}

output "otlp_endpoint" {
  description = "Endpoint base OTLP/HTTP usado pelo OpenTelemetry Collector."
  value       = "http://loki-gateway.${helm_release.this.namespace}.svc.cluster.local/otlp"
}
