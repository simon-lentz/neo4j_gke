# Bootstrap environment for state bucket and KMS key.
# See versions.tf for backend configuration and CLAUDE.md for migration steps.

provider "google" {
  project = var.project_id
}

# Audit logging for KMS and GCS (DATA_READ/DATA_WRITE audit logs)
# Called first to create logs bucket before state bucket needs it for access logging.
module "audit_logging" {
  source = "../../modules/audit_logging"

  project_id           = var.project_id
  logs_bucket_location = var.bucket_location

  enable_kms_audit_logs = var.enable_audit_logging
  enable_gcs_audit_logs = var.enable_audit_logging

  labels = var.labels
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  project_id      = var.project_id
  bucket_location = var.bucket_location
  kms_location    = var.kms_location

  bucket_name              = var.bucket_name
  bucket_versioning        = var.bucket_versioning
  retention_period_seconds = var.retention_period_seconds
  rotation_period          = var.rotation_period
  labels                   = var.labels
  randomize_bucket_name    = var.randomize_bucket_name
  force_destroy            = var.force_destroy

  # Prefix for bootstrap state; downstream layers (e.g., dev) read from this prefix.
  backend_prefix = "bootstrap"

  # Enable access logging on the state bucket, writing to the audit logs bucket.
  access_logs_bucket = var.enable_audit_logging ? module.audit_logging.logs_bucket_name : null
}