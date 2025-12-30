variable "project_id" {
  type        = string
  description = "GCP project to create GKE cluster in."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "region" {
  type        = string
  description = "GCP region for the GKE cluster."
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a valid GCP region (e.g., us-central1)."
  }
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE Autopilot cluster."
  default     = "neo4j-cluster"
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must match GKE naming constraints (1-40 chars, lowercase, start with letter)."
  }
}

variable "network_id" {
  type        = string
  description = "The VPC network ID (self_link or ID) for the cluster."
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID (self_link or ID) for the cluster."
}

variable "pods_range_name" {
  type        = string
  description = "Name of the secondary IP range for pods."
}

variable "services_range_name" {
  type        = string
  description = "Name of the secondary IP range for services."
}

variable "master_ipv4_cidr" {
  type        = string
  description = "CIDR block for the GKE master network (must be /28)."
  default     = "172.16.0.0/28"
  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr, 0)) && can(regex("/28$", var.master_ipv4_cidr))
    error_message = "master_ipv4_cidr must be a valid /28 CIDR block."
  }
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Whether the master's internal IP address is used as the cluster endpoint."
  default     = false
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "List of CIDR blocks authorized to access the master endpoint."
  default     = []
}

variable "release_channel" {
  type        = string
  description = "GKE release channel: RAPID, REGULAR, or STABLE."
  default     = "REGULAR"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "maintenance_start_time" {
  type        = string
  description = "Start time for the maintenance window in RFC3339 format."
  default     = "2025-01-01T09:00:00Z"
}

variable "maintenance_end_time" {
  type        = string
  description = "End time for the maintenance window in RFC3339 format."
  default     = "2025-01-01T17:00:00Z"
}

variable "maintenance_recurrence" {
  type        = string
  description = "RRULE for maintenance window recurrence."
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection for the cluster."
  default     = true
}

variable "enable_container_api" {
  type        = bool
  description = "Whether to enable the Container API. Set to false if already enabled."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the cluster."
  default     = {}
}
