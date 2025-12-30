variable "project_id" {
  type        = string
  description = "GCP project ID."
  nullable    = false
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "Project ID must match GCP constraints."
  }
}

# Buckets can be region, dual-region code, or multi-region (e.g. us-central1, NAM4, US)
variable "bucket_location" {
  type        = string
  description = "Location for the state bucket (region, dual-region code, or multi-region)."
}

variable "bucket_name" {
  type        = string
  description = "Override name for the state bucket (must be globally unique). If null, computed."
  default     = null
  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][-a-z0-9_.]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must match GCS naming constraints (3-63 chars, lowercase, start/end with alphanumeric)."
  }
}

variable "bucket_versioning" {
  type        = bool
  description = "Enable versioning for the state bucket."
  default     = false
}

variable "randomize_bucket_name" {
  type        = bool
  description = "Append a short random suffix to the computed bucket name to avoid collisions."
  default     = false
}

variable "storage_class" {
  type        = string
  default     = "STANDARD"
  description = "GCS storage class."
  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "Storage class must be one of STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "labels" {
  type        = map(string)
  description = "Optional resource labels."
  default     = {}
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket destroy even if it contains objects (use with caution)."
  default     = false
}

variable "soft_delete_retention_seconds" {
  type        = number
  description = "Soft delete retention (seconds). Use 0 to disable; otherwise 7-90 days (604800-7776000). Default 7 days."
  default     = 604800
  validation {
    condition = (
      var.soft_delete_retention_seconds == 0
      || (var.soft_delete_retention_seconds >= 604800 && var.soft_delete_retention_seconds <= 7776000)
    )
    error_message = "Must be 0 (disable), or 604800-7776000 seconds (7-90 days)."
  }
}


variable "retention_period_seconds" {
  type        = number
  description = "Optional bucket retention period in seconds. Null to disable retention policy."
  default     = null
  # Use a ternary to avoid evaluating `>=` on null during validation (import runs validations).
  validation {
    condition     = var.retention_period_seconds == null ? true : var.retention_period_seconds >= 86400
    error_message = "Retention, if set, must be >= 86400 seconds (1 day)."
  }
}

# KMS controls
variable "kms_location" {
  type        = string
  description = "KMS key ring location. Must be compatible with bucket_location."
  default     = null
  # Permit omission of kms_location when bucket_location is:
  # - a single region (regex),
  # - one of the mapped multi-regions, or
  # - one of the predefined dual regions we map (NAM4/EUR4).
  validation {
    condition = (
      var.kms_location != null
      || can(regex("^[a-z]+-[a-z0-9]+\\d$", var.bucket_location))
      || contains(["US", "EU", "ASIA", "NAM4", "EUR4"], upper(var.bucket_location))
    )
    error_message = "kms_location is required unless bucket_location is a single region or one of: US, EU, ASIA, NAM4, EUR4."
  }
}

variable "kms_key_ring_name" {
  type        = string
  description = "Name of the KMS key ring. If null, computed."
  default     = null
}

variable "kms_key_name" {
  type        = string
  description = "Name of the KMS crypto key."
  default     = "tfstate-key"
}

variable "kms_protection_level" {
  type        = string
  default     = "SOFTWARE"
  description = "'SOFTWARE', 'HSM', 'EXTERNAL', 'EXTERNAL_VPC'. Defaults to 'SOFTWARE'."
  validation {
    condition     = contains(["SOFTWARE", "HSM", "EXTERNAL", "EXTERNAL_VPC"], var.kms_protection_level)
    error_message = "kms_protection_level must be SOFTWARE, HSM, EXTERNAL, or EXTERNAL_VPC"
  }
}

variable "rotation_period" {
  type        = number
  description = "Rotation period for the KMS key, in seconds. Null to disable automatic rotation."
  default     = null
  # Same pattern: avoid evaluating arithmetic with null.
  validation {
    condition     = var.rotation_period == null ? true : (var.rotation_period >= 86400 && var.rotation_period % 60 == 0)
    error_message = "Rotation period must be null or a multiple of 60 seconds and at least 86400 seconds."
  }
}

# IAM bindings: role -> list of members
variable "bucket_iam" {
  description = "Additional IAM for the state bucket: map(role => [members])."
  type        = map(list(string))
  default     = {}
}

variable "kms_iam" {
  description = "Additional IAM for the KMS crypto key: map(role => [members])."
  type        = map(list(string))
  default     = {}
}

variable "additional_project_services" {
  type        = list(string)
  description = "Extra APIs to enable in addition to required_apis."
  default     = []
}

# Backend prefix (directory for state objects)
variable "backend_prefix" {
  type        = string
  description = "GCS backend prefix for state objects."
  default     = "tofu/state"
}