variable "project_id" {
  type        = string
  description = "GCP project to create VPC resources in."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "region" {
  type        = string
  description = "GCP region for regional resources (subnet, Cloud NAT)."
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a valid GCP region (e.g., us-central1)."
  }
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC network."
  default     = "neo4j-vpc"
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.vpc_name))
    error_message = "vpc_name must match GCP resource naming constraints."
  }
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet. Defaults to vpc_name-subnet."
  default     = null
}

variable "subnet_ip_range" {
  type        = string
  description = "Primary IP CIDR range for the subnet (node IPs)."
  default     = "10.0.0.0/24"
  validation {
    condition     = can(cidrhost(var.subnet_ip_range, 0))
    error_message = "subnet_ip_range must be a valid CIDR block."
  }
}

variable "pods_ip_range" {
  type        = string
  description = "Secondary IP CIDR range for GKE pods."
  default     = "10.1.0.0/16"
  validation {
    condition     = can(cidrhost(var.pods_ip_range, 0))
    error_message = "pods_ip_range must be a valid CIDR block."
  }
}

variable "services_ip_range" {
  type        = string
  description = "Secondary IP CIDR range for GKE services."
  default     = "10.2.0.0/20"
  validation {
    condition     = can(cidrhost(var.services_ip_range, 0))
    error_message = "services_ip_range must be a valid CIDR block."
  }
}

variable "pods_range_name" {
  type        = string
  description = "Name for the pods secondary range."
  default     = "pods"
}

variable "services_range_name" {
  type        = string
  description = "Name for the services secondary range."
  default     = "services"
}

variable "enable_cloud_nat" {
  type        = bool
  description = "Whether to create Cloud NAT for egress from private nodes."
  default     = true
}

variable "nat_ip_allocate_option" {
  type        = string
  description = "How NAT IPs are allocated: AUTO_ONLY or MANUAL_ONLY."
  default     = "AUTO_ONLY"
  validation {
    condition     = contains(["AUTO_ONLY", "MANUAL_ONLY"], var.nat_ip_allocate_option)
    error_message = "nat_ip_allocate_option must be AUTO_ONLY or MANUAL_ONLY."
  }
}

variable "nat_source_subnetwork_ip_ranges_to_nat" {
  type        = string
  description = "Which subnet IP ranges to NAT."
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to resources."
  default     = {}
}
