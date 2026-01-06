output "logs_bucket_name" {
  description = "Name of the audit logs bucket. Can be used as access_logs_bucket for other buckets."
  value       = google_storage_bucket.logs.name
}

output "logs_bucket_url" {
  description = "GCS URL of the audit logs bucket."
  value       = "gs://${google_storage_bucket.logs.name}"
}

output "logs_bucket_self_link" {
  description = "Self link of the audit logs bucket."
  value       = google_storage_bucket.logs.self_link
}

output "kms_audit_logs_enabled" {
  description = "Whether KMS audit logs are enabled."
  value       = var.enable_kms_audit_logs
}

output "gcs_audit_logs_enabled" {
  description = "Whether GCS audit logs are enabled."
  value       = var.enable_gcs_audit_logs
}

output "container_audit_logs_enabled" {
  description = "Whether GKE Container API audit logs are enabled."
  value       = var.enable_container_audit_logs
}

output "log_sink_name" {
  description = "Name of the Cloud Logging sink (empty if disabled or no services enabled)."
  value       = var.enable_log_sink && length(local.sink_filter_services) > 0 ? google_logging_project_sink.audit_sink[0].name : ""
}

output "log_sink_writer_identity" {
  description = "Service account identity used by the sink (empty if disabled or no services enabled)."
  value       = var.enable_log_sink && length(local.sink_filter_services) > 0 ? google_logging_project_sink.audit_sink[0].writer_identity : ""
}
