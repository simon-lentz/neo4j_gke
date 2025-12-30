variable "project_id" {
  type        = string
  description = "GCP project in which to create the WIF pool and provider."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "pool_id" {
  type        = string
  description = "Workload Identity Pool ID (short name)."
  default     = "github-pool"
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{2,30}[a-z0-9]$", var.pool_id))
    error_message = "pool_id must be 4-32 chars, lowercase alphanumeric or hyphen."
  }
}

variable "provider_id" {
  type        = string
  description = "Workload Identity Provider ID (short name)."
  default     = "github-actions"
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{2,30}[a-z0-9]$", var.provider_id))
    error_message = "provider_id must be 4-32 chars, lowercase alphanumeric or hyphen."
  }
}

variable "issuer_uri" {
  type        = string
  description = "OIDC issuer. Default is GitHub Actions OIDC."
  default     = "https://token.actions.githubusercontent.com"

  validation {
    condition     = can(regex("^https://", var.issuer_uri))
    error_message = "issuer_uri must begin with https://"
  }
}


# Selectors (compose into attribute_condition)
variable "allowed_repositories" {
  type        = set(string)
  description = "Set of allowed GitHub repositories (org/repo)."
  default     = []
  validation {
    condition     = alltrue([for r in var.allowed_repositories : can(regex("^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$", r))])
    error_message = "Each value in allowed_repositories must be <org>/<repo>."
  }
}

variable "allowed_repository_owners" {
  type        = set(string)
  description = "Optional allowed GitHub orgs (repository_owner)."
  default     = []
  validation {
    condition     = alltrue([for o in var.allowed_repository_owners : can(regex("^([A-Za-z0-9_.-]+)$", o))])
    error_message = "Each repository owner must be a simple org/user name."
  }
}

variable "allowed_refs" {
  type        = list(string)
  description = "Optional list of refs to allow. Use exact ref (e.g., refs/heads/main) or prefix wildcard (e.g., refs/heads/release/*)."
  default     = []
  validation {
    condition = alltrue([
      for r in var.allowed_refs : (
        startswith(r, "refs/") && !endswith(r, "/*")) || (startswith(r, "refs/") && endswith(r, "/*")
      )
    ])
    error_message = "Each ref must be an exact 'refs/...' or a prefix 'refs/.../*'."
  }
}


variable "allowed_audiences" {
  type        = set(string)
  description = "Optional allowed audience (aud) values for the OIDC token."
  default     = []
}

variable "attribute_mapping_extra" {
  type        = map(string)
  description = "Optional extra assertion -> attribute pairs to merge into the base mapping."
  default     = {}
}

variable "attribute_condition_override" {
  type        = string
  description = "If set, use this CEL expression verbatim for provider.attribute_condition."
  default     = null
}

variable "prevent_destroy_pool" {
  type        = bool
  description = "Prevent accidental destroy of the pool in production."
  default     = true
}

variable "prevent_destroy_provider" {
  type        = bool
  description = "Prevent accidental destroy of the provider in production."
  default     = true
}