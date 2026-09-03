resource "helm_release" "this" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
  wait            = true

  values = [yamlencode({
    controller = {
      replicaCount = 1

      ingressClassResource = {
        enabled         = true
        name            = "nginx"
        default         = false
        controllerValue = "k8s.io/ingress-nginx"
      }

      service = {
        enabled                  = true
        type                     = "LoadBalancer"
        externalTrafficPolicy    = "Cluster"
        loadBalancerSourceRanges = var.load_balancer_source_ranges
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
      }

      metrics = {
        enabled = false
      }
    }

    defaultBackend = {
      enabled = false
    }
  })]
}

data "kubernetes_service_v1" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [helm_release.this]
}
