variable "project_id" {
  type        = string
  description = "The GCP project ID where the state bucket will be created."
}

variable "bucket_location" {
  type        = string
  description = "The GCS location for the state bucket (e.g., us-central1, US)."
}

variable "kms_location" {
  type        = string
  description = "The Cloud KMS location for the encryption key (often same as bucket_location)."
}

variable "bucket_name" {
  type        = string
  description = "Override name for the state bucket. If null, a name is computed."
  default     = null
}

variable "bucket_versioning" {
  type        = bool
  description = "Enable object versioning on the state bucket."
  default     = false
}

variable "retention_period_seconds" {
  type        = number
  description = "Retention period in seconds for the state bucket objects. If null, no retention policy."
  default     = null
}

variable "rotation_period" {
  type        = number
  description = "KMS key rotation period in seconds. Default is 30 days (2592000)."
  default     = 2592000
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to resources."
  default = {
    component = "bootstrap"
  }
}

variable "randomize_bucket_name" {
  type        = bool
  description = "Append a random suffix to the bucket name for uniqueness."
  default     = true
}

variable "force_destroy" {
  type        = bool
  description = "Allow terraform to destroy the bucket even if it contains objects."
  default     = false
}

variable "enable_audit_logging" {
  type        = bool
  description = "Enable audit logging for KMS and GCS (DATA_READ/DATA_WRITE)."
  default     = true
}
