output "namespace" { value = kubernetes_namespace_v1.argocd.metadata[0].name }
output "release_name" { value = helm_release.argocd.name }
output "bootstrap_release_name" {
  value = var.bootstrap_gitops ? helm_release.gitops_bootstrap[0].name : null
}
output "root_application_name" { value = var.bootstrap_gitops ? "togglemaster-root" : null }
