# VPC Outputs
output "network_name" {
  description = "The name of the VPC network."
  value       = module.vpc.network_name
}

output "subnet_name" {
  description = "The name of the subnet."
  value       = module.vpc.subnet_name
}

# GKE Outputs
output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "The location (region) of the GKE cluster."
  value       = module.gke.cluster_location
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master."
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate."
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster."
  value       = module.gke.workload_identity_pool
}

# Backup Infrastructure Outputs
output "backup_bucket_name" {
  description = "The name of the backup bucket."
  value       = module.backup_bucket.bucket_name
}

output "backup_bucket_url" {
  description = "The gs:// URL of the backup bucket."
  value       = module.backup_bucket.bucket_url
}

output "backup_gsa_email" {
  description = "Email of the backup service account."
  value       = module.backup_sa.service_accounts["neo4j-backup"].email
}

output "backup_gsa_name" {
  description = "Full resource name of the backup service account."
  value       = module.backup_sa.service_accounts["neo4j-backup"].name
}

# Secrets Outputs
output "neo4j_password_secret_id" {
  description = "Secret ID for Neo4j admin password."
  value       = module.secrets.secret_ids["neo4j-admin-password-dev"]
}
