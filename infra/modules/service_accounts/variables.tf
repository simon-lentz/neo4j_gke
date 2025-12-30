variable "project_id" {
  type        = string
  description = "GCP project to create service accounts in."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "service_accounts" {
  description = <<EOT
Map of service-account-key => object describing each account.

'service-account-key' is a friendly handle you will use to reference this SA in outputs.

Fields:
- description   : string (required; used as display_name if display_name is omitted)
- display_name  : optional string
- disabled      : optional bool (defaults false) — if true, the SA is disabled after creation
EOT
  type = map(object({
    description  = string
    display_name = optional(string)
    disabled     = optional(bool, false)
  }))
  default = {}
}

variable "sa_prefix" {
  type        = string
  description = "Optional prefix applied to every service account ID (sanitized)."
  default     = ""
  validation {
    condition     = can(regex("^[A-Za-z0-9-]*$", var.sa_prefix))
    error_message = "sa_prefix may contain only letters, digits, and hyphens."
  }
}

variable "sa_suffix" {
  type        = string
  description = "Optional suffix applied to every service account ID (sanitized)."
  default     = ""
  validation {
    condition     = can(regex("^[A-Za-z0-9-]*$", var.sa_suffix))
    error_message = "sa_suffix may contain only letters, digits, and hyphens."
  }
}

variable "id_hash_suffix_from" {
  type        = string
  description = "Optional stable input whose sha1 (6 hex) is appended to the ID to reduce collisions. Not a security feature."
  default     = null
}

variable "prevent_destroy_service_accounts" {
  type        = bool
  description = "Protect service accounts from accidental destroy (recommended for prod)."
  default     = true
}