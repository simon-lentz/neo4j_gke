# Audit logging module for KMS and GCS
# Provides Cloud Audit Logs and GCS access logging

locals {
  logs_bucket_name = var.logs_bucket_name != null ? var.logs_bucket_name : "${var.project_id}-audit-logs"
}

# GCS bucket for storing access logs
resource "google_storage_bucket" "logs" {
  name                        = local.logs_bucket_name
  location                    = var.logs_bucket_location
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.log_retention_days
    }
  }

  labels = var.labels
}

# Cloud Audit Logs for KMS - captures cryptographic operations
resource "google_project_iam_audit_config" "kms_audit" {
  count   = var.enable_kms_audit_logs ? 1 : 0
  project = var.project_id
  service = "cloudkms.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Cloud Audit Logs for GCS - captures storage operations
resource "google_project_iam_audit_config" "gcs_audit" {
  count   = var.enable_gcs_audit_logs ? 1 : 0
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
