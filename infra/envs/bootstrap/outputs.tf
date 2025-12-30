output "state" { value = module.bootstrap.state }
output "backend" { value = module.bootstrap.backend } # type, bucket, and prefix
output "audit_logging" {
  description = "Audit logging configuration."
  value = {
    logs_bucket_name  = module.audit_logging.logs_bucket_name
    logs_bucket_url   = module.audit_logging.logs_bucket_url
    kms_audit_enabled = module.audit_logging.kms_audit_logs_enabled
    gcs_audit_enabled = module.audit_logging.gcs_audit_logs_enabled
  }
}