variable "project_id" {
  type        = string
  description = "GCP project to create secrets in."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "secrets" {
  description = <<EOT
Map of secret-key => object describing each secret.

Fields:
- description  : string (required) - description for the secret
- replication  : optional string - "automatic" (default) or "user_managed"
- labels       : optional map(string) - labels to apply to the secret
- expire_time  : optional string - RFC3339 timestamp when secret expires
- ttl          : optional string - duration string (e.g., "86400s") for TTL
- version_aliases : optional map(string) - version aliases mapping
EOT
  type = map(object({
    description     = string
    replication     = optional(string, "automatic")
    labels          = optional(map(string), {})
    expire_time     = optional(string)
    ttl             = optional(string)
    version_aliases = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.secrets : contains(["automatic", "user_managed"], v.replication)
    ])
    error_message = "replication must be 'automatic' or 'user_managed'."
  }
}

variable "accessors" {
  description = <<EOT
Map of secret-key => list of IAM members to grant secretAccessor role.
Example: { "my-secret" = ["serviceAccount:foo@proj.iam.gserviceaccount.com"] }
EOT
  type        = map(list(string))
  default     = {}
  validation {
    condition = alltrue(flatten([
      for members in values(var.accessors) : [
        for m in members : can(regex("^(user|serviceAccount|group|domain|allUsers|allAuthenticatedUsers):", m))
      ]
    ]))
    error_message = "Each accessor must be a valid IAM member format (e.g., serviceAccount:email, user:email)."
  }
}

variable "replication_locations" {
  description = "List of locations for user_managed replication. Only used when replication='user_managed'."
  type        = list(string)
  default     = ["us-central1", "us-east1"]
}

variable "enable_secret_manager_api" {
  description = "Whether to enable the Secret Manager API. Set to false if already enabled."
  type        = bool
  default     = true
}
