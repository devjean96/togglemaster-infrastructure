resource "helm_release" "this" {
  name             = "loki"
  repository       = var.chart_repository
  chart            = "loki"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
  wait            = true

  values = [yamlencode({
    deploymentMode = "Monolithic"

    loki = {
      auth_enabled = false
      commonConfig = {
        replication_factor = 1
      }
      schemaConfig = {
        configs = [{
          from         = "2024-04-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index = {
            prefix = "index_"
            period = "24h"
          }
        }]
      }
      storage = {
        type = "filesystem"
        filesystem = {
          chunks_directory = "/var/loki/chunks"
          rules_directory  = "/var/loki/rules"
        }
      }
      limits_config = {
        allow_structured_metadata = true
        retention_period          = var.retention_period
      }
      compactor = {
        retention_enabled    = true
        delete_request_store = "filesystem"
      }
    }

    singleBinary = {
      replicas = 1
      sidecar  = false
      persistence = {
        enabled = false
        dataVolumeParameters = {
          emptyDir = {
            sizeLimit = var.storage_size
          }
        }
      }
      podDisruptionBudget = {
        enabled = false
      }
      resources = var.resources
    }

    gateway = {
      enabled        = true
      replicas       = 1
      verboseLogging = false
      service = {
        type = "ClusterIP"
      }
      podDisruptionBudget = {
        enabled = false
      }
      resources = var.gateway_resources
    }

    read = {
      replicas = 0
    }
    write = {
      replicas = 0
    }
    backend = {
      replicas = 0
    }
    chunksCache = {
      enabled = false
    }
    resultsCache = {
      enabled = false
    }
    lokiCanary = {
      enabled = false
    }
    test = {
      enabled = false
    }
    monitoring = {
      dashboards = {
        enabled = false
      }
      rules = {
        enabled = false
      }
      alerts = {
        enabled = false
      }
      serviceMonitor = {
        enabled = false
      }
    }
  })]
}
