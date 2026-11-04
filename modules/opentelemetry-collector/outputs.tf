output "release_name" {
  value = helm_release.this.name
}

output "namespace" {
  value = helm_release.this.namespace
}

output "service_name" {
  value = "opentelemetry-collector"
}

output "otlp_http_endpoint" {
  value = "http://opentelemetry-collector.${helm_release.this.namespace}.svc.cluster.local:4318"
}

output "otlp_grpc_endpoint" {
  value = "opentelemetry-collector.${helm_release.this.namespace}.svc.cluster.local:4317"
}
