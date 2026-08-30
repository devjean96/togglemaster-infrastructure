resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  values = [yamlencode({
    server = {
      service = {
        type = var.service_type
      }
    }
  })]
}

resource "helm_release" "gitops_bootstrap" {
  count = var.bootstrap_gitops ? 1 : 0

  name      = "togglemaster-gitops-bootstrap"
  chart     = "${path.module}/bootstrap-chart"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  timeout         = 300

  values = [yamlencode({
    application = {
      name           = "togglemaster-root"
      repositoryUrl  = var.gitops_repository_url
      targetRevision = var.gitops_target_revision
      rootPath       = var.gitops_root_path
    }
  })]

  depends_on = [helm_release.argocd]
}
