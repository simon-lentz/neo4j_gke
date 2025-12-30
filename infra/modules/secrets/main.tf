locals {
  # Flatten accessors map into individual IAM bindings
  accessor_bindings = flatten([
    for secret_key, members in var.accessors : [
      for member in members : {
        secret_key = secret_key
        member     = member
        key        = "${secret_key}:${member}"
      }
    ]
  ])
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager" {
  count              = var.enable_secret_manager_api ? 1 : 0
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Create secrets
resource "google_secret_manager_secret" "secrets" {
  for_each  = var.secrets
  project   = var.project_id
  secret_id = each.key

  labels = each.value.labels

  dynamic "replication" {
    for_each = each.value.replication == "automatic" ? [1] : []
    content {
      auto {}
    }
  }

  dynamic "replication" {
    for_each = each.value.replication == "user_managed" ? [1] : []
    content {
      user_managed {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }

  # Optional expiration
  expire_time = each.value.expire_time
  ttl         = each.value.ttl

  # Version aliases (map attribute, not a block)
  version_aliases = each.value.version_aliases

  depends_on = [google_project_service.secretmanager]
}

# Grant secretAccessor role to specified members
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for binding in local.accessor_bindings : binding.key => binding
    if contains(keys(var.secrets), binding.secret_key)
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
