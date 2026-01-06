variable "project_id" {
  type        = string
  description = "GCP project ID."
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.project_id))
    error_message = "project_id must match GCP constraints."
  }
}

variable "region" {
  type        = string
  description = "GCP region."
  default     = "us-central1"
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket containing platform Terraform state."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod)."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

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
  default     = "neo4j-dev"
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
  description = "Additional namespaces allowed to access Neo4j (e.g., for monitoring, application pods)."
  default     = []
}

variable "neo4j_helm_repository" {
  type        = string
  description = "Helm repository URL for Neo4j chart."
  default     = "https://helm.neo4j.com/neo4j"
}

variable "neo4j_password_k8s_secret" {
  type        = string
  description = <<-EOT
    Name of an existing Kubernetes Secret containing the Neo4j password.
    If set, the password will NOT be fetched from Secret Manager into Terraform state.

    SECURITY: When null (default), the password is fetched from Secret Manager and
    passed to Helm, which stores it in Terraform state (encrypted by CMEK, but still
    present). For production, create the K8s secret externally (via CSI driver,
    External Secrets Operator, or kubectl) and provide its name here.

    The secret must have a key named 'NEO4J_AUTH' with value 'neo4j/<password>'.
  EOT
  default     = null
}

variable "backup_pod_label" {
  type        = string
  description = "Label value to identify backup pods for network policy. Pods with 'app.kubernetes.io/name' matching this value get backup network access."
  default     = "neo4j-backup"
}
