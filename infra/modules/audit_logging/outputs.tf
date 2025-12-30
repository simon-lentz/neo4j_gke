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
