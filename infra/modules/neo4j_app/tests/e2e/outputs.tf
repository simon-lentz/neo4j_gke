# E2E Test Outputs
# Pass through module outputs for test assertions

output "namespace" {
  description = "Kubernetes namespace where Neo4j is deployed."
  value       = module.neo4j_app.namespace
}

output "neo4j_instance_name" {
  description = "Name of the Neo4j instance."
  value       = module.neo4j_app.neo4j_instance_name
}

output "neo4j_bolt_service" {
  description = "Kubernetes service name for Bolt protocol access."
  value       = module.neo4j_app.neo4j_bolt_service
}

output "neo4j_bolt_port" {
  description = "Port for Neo4j Bolt protocol."
  value       = module.neo4j_app.neo4j_bolt_port
}

output "backup_ksa_name" {
  description = "Kubernetes service account for backups."
  value       = module.neo4j_app.backup_ksa_name
}

output "backup_bucket_url" {
  description = "GCS bucket URL for backups."
  value       = module.neo4j_app.backup_bucket_url
}

output "connection_info" {
  description = "Neo4j connection information."
  value       = module.neo4j_app.connection_info
}

output "network_policy_default_deny" {
  description = "Name of the default-deny network policy."
  value       = module.neo4j_app.network_policy_default_deny
}

output "network_policy_allow_neo4j" {
  description = "Name of the allow-neo4j network policy."
  value       = module.neo4j_app.network_policy_allow_neo4j
}

output "network_policy_allow_backup" {
  description = "Name of the allow-backup network policy."
  value       = module.neo4j_app.network_policy_allow_backup
}

output "network_policy_neo4j_to_backup" {
  description = "Name of the neo4j-to-backup egress network policy."
  value       = module.neo4j_app.network_policy_neo4j_to_backup
}

output "wi_binding_member" {
  description = "Workload Identity binding member string."
  value       = module.neo4j_app.wi_binding_member
}
