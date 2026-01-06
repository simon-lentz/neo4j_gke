# Ensure services are enabled before creating KMS & GCS resources
# Terraform will treat the whole set as a dependency.
# (This avoids race conditions after enabling APIs.)
# See provider guides for enabling multiple services.

resource "google_kms_key_ring" "state_ring" {
  name       = local.computed_ring
  location   = local.ring_location
  project    = var.project_id
  depends_on = [google_project_service.enabled]
}

resource "google_kms_crypto_key" "state_key" {
  name     = var.kms_key_name
  key_ring = google_kms_key_ring.state_ring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = var.rotation_period == null ? null : "${var.rotation_period}s"

  version_template {
    # https://cloud.google.com/kms/docs/reference/rest/v1/CryptoKeyVersionAlgorithm
    # Only symmetric encryption supported for encrypt/decrypt so we hardcode that here.
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }

  depends_on = [google_project_service.enabled]
}

data "google_storage_project_service_account" "gcs_sa" {
  project    = var.project_id
  depends_on = [google_project_service.enabled]
}

# Least-privilege grant: Cloud Storage service agent needs encrypt/decrypt on the key.
# This ensures callers don’t need KMS perms for normal state I/O, instead storage does envelope encryption via the service plane.
resource "google_kms_crypto_key_iam_member" "allow_gcs_key" {
  crypto_key_id = google_kms_crypto_key.state_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}

resource "google_storage_bucket" "state_bucket" {
  name                        = local.bucket_name
  location                    = var.bucket_location
  project                     = var.project_id
  storage_class               = var.storage_class
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels
  force_destroy               = var.force_destroy

  encryption {
    default_kms_key_name = google_kms_crypto_key.state_key.id
  }

  versioning { enabled = var.bucket_versioning }

  dynamic "retention_policy" {
    for_each = var.retention_period_seconds == null ? [] : [1]
    content {
      retention_period = var.retention_period_seconds
      # is_locked = true # expose as a separate input; locking is irreversible!
    }
  }

  dynamic "soft_delete_policy" {
    # Treat both null and 0 as "disable soft delete"
    for_each = var.soft_delete_retention_seconds == null || var.soft_delete_retention_seconds == 0 ? [] : [1]
    content {
      retention_duration_seconds = var.soft_delete_retention_seconds
    }
  }

  dynamic "logging" {
    for_each = var.access_logs_bucket != null ? [1] : []
    content {
      log_bucket = var.access_logs_bucket
    }
  }

  # Require KMS grant to exist before bucket creation to avoid "permission denied"
  depends_on = [
    google_project_service.enabled,
    google_kms_crypto_key_iam_member.allow_gcs_key
  ]
}

# Optional: attach additional (deduped) bucket IAM (role -> members)
locals {
  bucket_iam_pairs = flatten([
    for role, members in var.bucket_iam : [
      for m in distinct(members) : { role = role, member = m }
    ]
  ])
}
resource "google_storage_bucket_iam_member" "extra" {
  # Use deterministic key to avoid plan churn
  for_each = { for p in local.bucket_iam_pairs : "${p.role}:${p.member}" => p }
  bucket   = google_storage_bucket.state_bucket.name
  role     = each.value.role
  member   = each.value.member
}

# Optional: attach additional (deduped) KMS IAM (role -> members)
locals {
  kms_iam_pairs = flatten([
    for role, members in var.kms_iam : [
      for m in distinct(members) : { role = role, member = m }
    ]
  ])
}
resource "google_kms_crypto_key_iam_member" "extra" {
  # Deterministic key here as well
  for_each      = { for p in local.kms_iam_pairs : "${p.role}:${p.member}" => p }
  crypto_key_id = google_kms_crypto_key.state_key.id
  role          = each.value.role
  member        = each.value.member
}