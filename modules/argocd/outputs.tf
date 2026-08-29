output "namespace" { value = kubernetes_namespace_v1.argocd.metadata[0].name }
output "release_name" { value = helm_release.argocd.name }
output "root_application_name" { value = var.bootstrap_gitops ? "togglemaster-root" : null }
