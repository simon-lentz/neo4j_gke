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

variable "state_bucket_name" {
  type        = string
  description = "Name of state bucket to enable access logging on. If null, GCS access logging is skipped."
  default     = null
}

variable "enable_gcs_access_logging" {
  type        = bool
  description = "Enable GCS access logging on state bucket."
  default     = true
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
