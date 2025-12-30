output "state" {
  description = "State backend resources."
  value = {
    bucket_name             = google_storage_bucket.state_bucket.name
    bucket_self_link        = google_storage_bucket.state_bucket.self_link
    location                = google_storage_bucket.state_bucket.location
    storage_class           = google_storage_bucket.state_bucket.storage_class
    kms_key_name            = google_kms_crypto_key.state_key.id
    key_ring                = google_kms_key_ring.state_ring.id
    gcs_service_agent_email = data.google_storage_project_service_account.gcs_sa.email_address

  }
}

# A ready-to-paste backend stanza (users still paste this into their root)
output "backend" {
  description = "GCS backend snippet for OpenTofu."
  value = {
    type = "gcs"
    config = {
      bucket = google_storage_bucket.state_bucket.name
      prefix = var.backend_prefix
    }
  }
}