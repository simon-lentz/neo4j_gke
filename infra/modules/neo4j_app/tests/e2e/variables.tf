# E2E Test Variables
# Accepts direct inputs for test isolation

# Provider configuration
variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region."
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name."
}

variable "cluster_location" {
  type        = string
  description = "GKE cluster location (region or zone)."
}

# Module inputs
variable "workload_identity_pool" {
  type        = string
  description = "Workload Identity pool (format: PROJECT_ID.svc.id.goog)."
}

variable "backup_gsa_email" {
  type        = string
  description = "Email of the GCP service account for backups."
}

variable "backup_gsa_name" {
  type        = string
  description = "Full resource name of the backup service account."
}

variable "backup_bucket_url" {
  type        = string
  description = "GCS bucket URL for Neo4j backups."
}

variable "neo4j_password" {
  type        = string
  description = "Neo4j admin password."
  sensitive   = true
}

variable "neo4j_namespace" {
  type        = string
  description = "Kubernetes namespace for Neo4j deployment."
  default     = "neo4j"
}

variable "neo4j_instance_name" {
  type        = string
  description = "Name for the Neo4j instance."
  default     = "neo4j-test"
}

variable "backup_pod_label" {
  type        = string
  description = "Label value to identify backup pods for network policy."
  default     = "neo4j-backup"
}
