output "bucket_name" {
  description = "The name of the backup bucket."
  value       = google_storage_bucket.backups.name
}

output "bucket_url" {
  description = "The gs:// URL of the backup bucket."
  value       = "gs://${google_storage_bucket.backups.name}"
}

output "bucket_self_link" {
  description = "The self_link of the backup bucket."
  value       = google_storage_bucket.backups.self_link
}

output "bucket_location" {
  description = "The location of the backup bucket."
  value       = google_storage_bucket.backups.location
}

output "kms_key_name" {
  description = "The KMS key used for bucket encryption, if any."
  value       = var.kms_key_name
}
