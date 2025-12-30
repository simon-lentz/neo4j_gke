# Neo4j Application - Dev Environment
#
# This layer deploys Neo4j to the GKE cluster provisioned by the platform layer.
# It configures:
# - Kubernetes namespace with labels
# - Service account with Workload Identity for backups
# - NetworkPolicies for security
# - Neo4j Helm release

# Read platform layer outputs
data "terraform_remote_state" "platform" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.environment
  }
}

# Read Neo4j admin password from Secret Manager
data "google_secret_manager_secret_version" "neo4j_password" {
  project = var.project_id
  secret  = data.terraform_remote_state.platform.outputs.neo4j_password_secret_id
}

# Kubernetes namespace for Neo4j
resource "kubernetes_namespace" "neo4j" {
  metadata {
    name = var.neo4j_namespace
    labels = {
      "app.kubernetes.io/name"       = "neo4j"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}

# Kubernetes Service Account for backups with Workload Identity annotation
resource "kubernetes_service_account" "neo4j_backup" {
  metadata {
    name      = "neo4j-backup"
    namespace = kubernetes_namespace.neo4j.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = data.terraform_remote_state.platform.outputs.backup_gsa_email
    }
    labels = {
      "app.kubernetes.io/name"       = "neo4j-backup"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Workload Identity binding: GSA -> KSA
resource "google_service_account_iam_member" "backup_wi_binding" {
  service_account_id = data.terraform_remote_state.platform.outputs.backup_gsa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.terraform_remote_state.platform.outputs.workload_identity_pool}[${kubernetes_namespace.neo4j.metadata[0].name}/${kubernetes_service_account.neo4j_backup.metadata[0].name}]"
}

# Default deny NetworkPolicy - block all traffic by default
resource "kubernetes_network_policy" "default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.neo4j.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# Allow Neo4j internal traffic
resource "kubernetes_network_policy" "allow_neo4j" {
  metadata {
    name      = "allow-neo4j"
    namespace = kubernetes_namespace.neo4j.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "neo4j"
      }
    }

    # Allow Bolt protocol (7687) and HTTP browser (7474) ingress
    ingress {
      ports {
        port     = "7687"
        protocol = "TCP"
      }
      ports {
        port     = "7474"
        protocol = "TCP"
      }
      # Allow from same namespace
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.neo4j_namespace
          }
        }
      }
      # Allow from additional namespaces
      dynamic "from" {
        for_each = var.allowed_ingress_namespaces
        content {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = from.value
            }
          }
        }
      }
    }

    # Allow egress for backups to GCS and DNS resolution
    egress {
      # DNS
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    egress {
      # HTTPS for GCS and metadata server
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}

# Neo4j Helm release
resource "helm_release" "neo4j" {
  name       = var.neo4j_instance_name
  repository = var.neo4j_helm_repository
  chart      = "neo4j"
  version    = var.neo4j_chart_version
  namespace  = kubernetes_namespace.neo4j.metadata[0].name

  # Use values file for base configuration
  values = [file("${path.module}/values/neo4j.yaml")]

  # Override sensitive values
  set_sensitive {
    name  = "neo4j.password"
    value = data.google_secret_manager_secret_version.neo4j_password.secret_data
  }

  # Override instance name
  set {
    name  = "neo4j.name"
    value = var.neo4j_instance_name
  }

  # Override storage size
  set {
    name  = "volumes.data.defaultStorageClass.requests.storage"
    value = var.neo4j_storage_size
  }

  depends_on = [
    kubernetes_namespace.neo4j,
    kubernetes_network_policy.allow_neo4j
  ]

  timeout = 600 # 10 minutes for initial deployment
}
