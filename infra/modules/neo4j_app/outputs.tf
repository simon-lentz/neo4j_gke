# Namespace
output "namespace" {
  description = "Kubernetes namespace where Neo4j is deployed."
  value       = kubernetes_namespace.neo4j.metadata[0].name
}

# Neo4j Service
output "neo4j_instance_name" {
  description = "Name of the Neo4j instance."
  value       = var.neo4j_instance_name
}

output "neo4j_bolt_service" {
  description = "Kubernetes service name for Bolt protocol access."
  value       = "${var.neo4j_instance_name}-lb-neo4j"
}

output "neo4j_bolt_port" {
  description = "Port for Neo4j Bolt protocol."
  value       = 7687
}

# Backup Configuration
output "backup_ksa_name" {
  description = "Kubernetes service account for backups."
  value       = kubernetes_service_account.neo4j_backup.metadata[0].name
}

output "backup_bucket_url" {
  description = "GCS bucket URL for backups."
  value       = var.backup_bucket_url
}

# Connection Info
output "connection_info" {
  description = "Neo4j connection information."
  value = {
    bolt_uri     = "bolt://${var.neo4j_instance_name}-lb-neo4j.${var.neo4j_namespace}.svc.cluster.local:7687"
    http_uri     = "http://${var.neo4j_instance_name}-lb-neo4j.${var.neo4j_namespace}.svc.cluster.local:7474"
    username     = "neo4j"
    password_ref = var.neo4j_password_secret_id != null ? "Secret Manager: ${var.neo4j_password_secret_id}" : "Provided via variable"
  }
}

# Network Policy Names (for verification in tests)
output "network_policy_default_deny" {
  description = "Name of the default-deny network policy."
  value       = kubernetes_network_policy.default_deny.metadata[0].name
}

output "network_policy_allow_neo4j" {
  description = "Name of the allow-neo4j network policy."
  value       = kubernetes_network_policy.allow_neo4j.metadata[0].name
}

output "network_policy_allow_backup" {
  description = "Name of the allow-backup network policy."
  value       = kubernetes_network_policy.allow_backup.metadata[0].name
}

output "network_policy_neo4j_to_backup" {
  description = "Name of the neo4j-to-backup egress network policy."
  value       = kubernetes_network_policy.neo4j_to_backup.metadata[0].name
}

# Workload Identity binding member (for verification)
output "wi_binding_member" {
  description = "Workload Identity binding member string."
  value       = "serviceAccount:${var.workload_identity_pool}[${kubernetes_namespace.neo4j.metadata[0].name}/${kubernetes_service_account.neo4j_backup.metadata[0].name}]"
}
