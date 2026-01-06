# E2E Test Wrapper
# Calls the neo4j_app module with test configuration

module "neo4j_app" {
  source = "../.."

  project_id             = var.project_id
  workload_identity_pool = var.workload_identity_pool
  backup_gsa_email       = var.backup_gsa_email
  backup_gsa_name        = var.backup_gsa_name
  backup_bucket_url      = var.backup_bucket_url
  neo4j_password         = var.neo4j_password
  neo4j_namespace        = var.neo4j_namespace
  neo4j_instance_name    = var.neo4j_instance_name
  backup_pod_label       = var.backup_pod_label

  # Test environment settings
  environment = "test"
}
