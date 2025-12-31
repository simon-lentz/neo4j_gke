# Test variant of Neo4j app layer variables
# Accepts direct inputs instead of reading from remote state

variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region."
}

# Cluster configuration (from GKE module outputs)
variable "cluster_name" {
  type        = string
  description = "GKE cluster name."
}

variable "cluster_location" {
  type        = string
  description = "GKE cluster location (region or zone)."
}

# Workload Identity configuration (from GKE module outputs)
variable "workload_identity_pool" {
  type        = string
  description = "Workload Identity pool (format: PROJECT_ID.svc.id.goog)."
}

# Service account configuration (from service_accounts module outputs)
variable "backup_gsa_email" {
  type        = string
  description = "Email of the GCP service account for backups."
}

variable "backup_gsa_name" {
  type        = string
  description = "Full resource name of the backup service account."
}

# Backup bucket URL (from backup_bucket module outputs)
variable "backup_bucket_url" {
  type        = string
  description = "GCS bucket URL for Neo4j backups."
}

# Neo4j password (direct input for testing, no Secret Manager)
variable "neo4j_password" {
  type        = string
  description = "Neo4j admin password."
  sensitive   = true
}

# Neo4j configuration
variable "neo4j_chart_version" {
  type        = string
  description = "Version of the Neo4j Helm chart to deploy."
  default     = "5.26.0"
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

variable "neo4j_storage_size" {
  type        = string
  description = "Storage size for Neo4j data volume."
  default     = "10Gi"
}

variable "enable_neo4j_browser" {
  type        = bool
  description = "Enable HTTP for Neo4j Browser access (port 7474)."
  default     = true
}

variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Additional namespaces allowed to access Neo4j."
  default     = []
}

variable "neo4j_helm_repository" {
  type        = string
  description = "Helm repository URL for Neo4j chart."
  default     = "https://helm.neo4j.com/neo4j"
}
