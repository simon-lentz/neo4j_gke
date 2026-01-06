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
# WARNING: google_project_iam_audit_config is authoritative per service.
# It will overwrite any existing audit config for this service in the project.
resource "google_project_iam_audit_config" "kms_audit" {
  count   = var.enable_kms_audit_logs ? 1 : 0
  project = var.project_id
  service = "cloudkms.googleapis.com"

  audit_log_config {
    log_type         = "DATA_READ"
    exempted_members = var.audit_log_exempted_members
  }
  audit_log_config {
    log_type         = "DATA_WRITE"
    exempted_members = var.audit_log_exempted_members
  }
}

# Cloud Audit Logs for GCS - captures storage operations
# WARNING: google_project_iam_audit_config is authoritative per service.
resource "google_project_iam_audit_config" "gcs_audit" {
  count   = var.enable_gcs_audit_logs ? 1 : 0
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type         = "DATA_READ"
    exempted_members = var.audit_log_exempted_members
  }
  audit_log_config {
    log_type         = "DATA_WRITE"
    exempted_members = var.audit_log_exempted_members
  }
}

# Cloud Audit Logs for GKE Container API - captures cluster operations
# WARNING: google_project_iam_audit_config is authoritative per service.
resource "google_project_iam_audit_config" "container_audit" {
  count   = var.enable_container_audit_logs ? 1 : 0
  project = var.project_id
  service = "container.googleapis.com"

  audit_log_config {
    log_type         = "DATA_READ"
    exempted_members = var.audit_log_exempted_members
  }
  audit_log_config {
    log_type         = "DATA_WRITE"
    exempted_members = var.audit_log_exempted_members
  }
}

# Build sink filter dynamically based on enabled audit logs
locals {
  sink_filter_services = compact([
    var.enable_kms_audit_logs ? "protoPayload.serviceName=\"cloudkms.googleapis.com\"" : "",
    var.enable_gcs_audit_logs ? "protoPayload.serviceName=\"storage.googleapis.com\"" : "",
    var.enable_container_audit_logs ? "protoPayload.serviceName=\"container.googleapis.com\"" : "",
  ])
  sink_filter = join(" OR\n    ", local.sink_filter_services)
}

# Cloud Logging sink to route audit logs to GCS bucket
resource "google_logging_project_sink" "audit_sink" {
  count       = var.enable_log_sink && length(local.sink_filter_services) > 0 ? 1 : 0
  name        = "${var.project_id}-audit-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"

  # Filter for enabled audit log services only
  filter = local.sink_filter

  unique_writer_identity = true
}

# Grant sink writer permission to bucket
resource "google_storage_bucket_iam_member" "sink_writer" {
  count  = var.enable_log_sink && length(local.sink_filter_services) > 0 ? 1 : 0
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit_sink[0].writer_identity
}
