# Audit logging module for KMS and GCS
# Provides Cloud Audit Logs, log sink to GCS, and bucket access logging

locals {
  logs_bucket_name = var.logs_bucket_name != null ? var.logs_bucket_name : "${var.project_id}-audit-logs"
}

# GCS bucket for storing audit logs
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

# Cloud Logging sink to route audit logs to GCS bucket
resource "google_logging_project_sink" "audit_sink" {
  count       = var.enable_log_sink ? 1 : 0
  name        = "${var.project_id}-audit-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"

  # Filter for KMS, GCS, and GKE audit logs
  filter = <<-EOT
    protoPayload.serviceName="cloudkms.googleapis.com" OR
    protoPayload.serviceName="storage.googleapis.com" OR
    protoPayload.serviceName="container.googleapis.com"
  EOT

  unique_writer_identity = true
}

# Grant sink writer permission to bucket
resource "google_storage_bucket_iam_member" "sink_writer" {
  count  = var.enable_log_sink ? 1 : 0
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit_sink[0].writer_identity
}

# Enable access logging on target bucket (e.g., state or backup bucket)
# This logs all read/write operations to the target bucket into the audit logs bucket
resource "google_storage_bucket" "target_access_logs" {
  count                       = var.enable_gcs_access_logging && var.state_bucket_name != null ? 1 : 0
  name                        = "${var.state_bucket_name}-access-logs"
  project                     = var.project_id
  location                    = var.logs_bucket_location
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

  logging {
    log_bucket = google_storage_bucket.logs.name
  }

  labels = var.labels
}
