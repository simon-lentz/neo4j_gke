variable "project_id" {
  type        = string
  description = "GCP project ID."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "logs_bucket_location" {
  type        = string
  description = "Location for logs bucket."
  default     = "US"
}

variable "logs_bucket_name" {
  type        = string
  description = "Custom name for logs bucket. If null, auto-generated as {project_id}-audit-logs."
  default     = null
}

variable "enable_kms_audit_logs" {
  type        = bool
  description = "Enable Cloud Audit Logs for Cloud KMS DATA_READ and DATA_WRITE."
  default     = true
}

variable "enable_gcs_audit_logs" {
  type        = bool
  description = "Enable Cloud Audit Logs for Cloud Storage DATA_READ and DATA_WRITE."
  default     = true
}

variable "enable_container_audit_logs" {
  type        = bool
  description = "Enable Cloud Audit Logs for GKE Container API DATA_READ and DATA_WRITE."
  default     = false
}

variable "audit_log_exempted_members" {
  type        = list(string)
  description = "List of identities exempt from audit logging (e.g., serviceAccount:...). Applied to all enabled audit configs. Note: google_project_iam_audit_config is authoritative per service and will overwrite existing audit settings for that service."
  default     = []
}

variable "enable_log_sink" {
  type        = bool
  description = "Create Cloud Logging sink to route audit logs to GCS bucket."
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in the bucket before deletion."
  default     = 365
  validation {
    condition     = var.log_retention_days >= 1
    error_message = "log_retention_days must be at least 1."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to logging resources."
  default     = {}
}
