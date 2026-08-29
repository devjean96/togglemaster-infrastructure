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

    extraObjects = var.bootstrap_gitops ? [
      {
        apiVersion = "argoproj.io/v1alpha1"
        kind       = "Application"
        metadata = {
          name      = "togglemaster-root"
          namespace = kubernetes_namespace_v1.argocd.metadata[0].name
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.gitops_repository_url
            targetRevision = var.gitops_target_revision
            path           = var.gitops_root_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = kubernetes_namespace_v1.argocd.metadata[0].name
          }
          syncPolicy = {
            automated = {
              prune      = true
              selfHeal   = true
              allowEmpty = false
            }
            syncOptions = [
              "ServerSideApply=true",
              "PruneLast=true"
            ]
          }
        }
      }
    ] : []
  })]
}
