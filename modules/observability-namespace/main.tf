resource "helm_release" "this" {
  name             = "observability-namespace"
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 300
}
