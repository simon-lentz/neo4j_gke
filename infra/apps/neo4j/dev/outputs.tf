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
  value       = data.terraform_remote_state.platform.outputs.backup_bucket_url
}

# Connection Info
output "connection_info" {
  description = "Neo4j connection information."
  value = {
    bolt_uri     = "bolt://${var.neo4j_instance_name}-lb-neo4j.${var.neo4j_namespace}.svc.cluster.local:7687"
    http_uri     = "http://${var.neo4j_instance_name}-lb-neo4j.${var.neo4j_namespace}.svc.cluster.local:7474"
    username     = "neo4j"
    password_ref = "Secret Manager: ${data.terraform_remote_state.platform.outputs.neo4j_password_secret_id}"
  }
}
