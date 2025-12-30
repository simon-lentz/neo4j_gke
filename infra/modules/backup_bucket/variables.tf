variable "project_id" {
  type        = string
  description = "GCP project to create the backup bucket in."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name for the backup bucket."
  validation {
    condition     = can(regex("^[a-z0-9][-a-z0-9_.]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must match GCS naming constraints."
  }
}

variable "location" {
  type        = string
  description = "GCS location for the bucket (region, dual-region, or multi-region)."
}

variable "backup_sa_email" {
  type        = string
  description = "Email of the service account that will write backups."
  validation {
    condition     = can(regex("^.+@.+\\.iam\\.gserviceaccount\\.com$", var.backup_sa_email))
    error_message = "backup_sa_email must be a valid service account email."
  }
}

variable "storage_class" {
  type        = string
  description = "Storage class for the bucket."
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain backup objects before deletion (0 = no auto-delete)."
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 0
    error_message = "backup_retention_days must be non-negative."
  }
}

variable "backup_versions_to_keep" {
  type        = number
  description = "Number of noncurrent versions to retain (0 = delete immediately)."
  default     = 5
  validation {
    condition     = var.backup_versions_to_keep >= 0
    error_message = "backup_versions_to_keep must be non-negative."
  }
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket destruction even with objects (use only in dev)."
  default     = false
}

variable "enable_versioning" {
  type        = bool
  description = "Enable object versioning for recovery of deleted/overwritten backups."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the bucket."
  default     = {}
}

variable "kms_key_name" {
  type        = string
  description = "KMS key for bucket encryption. If null, uses Google-managed encryption."
  default     = null
}
