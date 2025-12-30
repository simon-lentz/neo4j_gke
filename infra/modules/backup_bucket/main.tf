# GCS bucket for Neo4j backups with security best practices
resource "google_storage_bucket" "backups" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  # Security: Uniform bucket-level access (no ACLs)
  uniform_bucket_level_access = true

  # Security: Prevent public access
  public_access_prevention = "enforced"

  # Enable versioning for backup recovery
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle rules for backup retention
  dynamic "lifecycle_rule" {
    for_each = var.backup_retention_days > 0 ? [1] : []
    content {
      condition {
        age = var.backup_retention_days
      }
      action {
        type = "Delete"
      }
    }
  }

  # Delete old versions
  dynamic "lifecycle_rule" {
    for_each = var.enable_versioning && var.backup_versions_to_keep > 0 ? [1] : []
    content {
      condition {
        num_newer_versions = var.backup_versions_to_keep
        with_state         = "ARCHIVED"
      }
      action {
        type = "Delete"
      }
    }
  }

  labels = var.labels

  # Optional CMEK encryption
  dynamic "encryption" {
    for_each = var.kms_key_name != null ? [1] : []
    content {
      default_kms_key_name = var.kms_key_name
    }
  }
}

# Grant backup service account permission to create objects
resource "google_storage_bucket_iam_member" "backup_creator" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.backup_sa_email}"
}

# Grant backup service account permission to view objects (for verification)
resource "google_storage_bucket_iam_member" "backup_viewer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.backup_sa_email}"
}
