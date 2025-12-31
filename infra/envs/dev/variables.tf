variable "project_id" {
  type        = string
  description = "GCP project ID for the dev environment."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "region" {
  type        = string
  description = "GCP region for resources."
  default     = "us-central1"
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a valid GCP region (e.g., us-central1)."
  }
}

variable "subnet_ip_range" {
  type        = string
  description = "Primary IP CIDR range for the subnet."
  default     = "10.0.0.0/24"
}

variable "pods_ip_range" {
  type        = string
  description = "Secondary IP CIDR range for GKE pods."
  default     = "10.1.0.0/16"
}

variable "services_ip_range" {
  type        = string
  description = "Secondary IP CIDR range for GKE services."
  default     = "10.2.0.0/20"
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket for OpenTofu state. Used to read bootstrap outputs for CMEK key."
}
