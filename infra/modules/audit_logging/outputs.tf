output "logs_bucket_name" {
  description = "Name of the audit logs bucket."
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

output "log_sink_name" {
  description = "Name of the Cloud Logging sink (empty if disabled)."
  value       = var.enable_log_sink ? google_logging_project_sink.audit_sink[0].name : ""
}

output "log_sink_writer_identity" {
  description = "Service account identity used by the sink."
  value       = var.enable_log_sink ? google_logging_project_sink.audit_sink[0].writer_identity : ""
}

output "access_logs_bucket_name" {
  description = "Name of the access logs bucket (empty if disabled)."
  value       = var.enable_gcs_access_logging && var.state_bucket_name != null ? google_storage_bucket.target_access_logs[0].name : ""
}
