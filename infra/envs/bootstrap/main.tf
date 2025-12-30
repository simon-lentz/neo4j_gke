# Local backend on purpose: no terraform { backend ... } here.

provider "google" {
  project = var.project_id
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

  # Keep the logical path stable across envs; env roots will set their own prefix too.
  backend_prefix = "tofu/state"
}

# Audit logging for KMS and GCS (DATA_READ/DATA_WRITE audit logs)
module "audit_logging" {
  source = "../../modules/audit_logging"

  project_id           = var.project_id
  logs_bucket_location = var.bucket_location

  enable_kms_audit_logs = var.enable_audit_logging
  enable_gcs_audit_logs = var.enable_audit_logging

  labels = var.labels
}