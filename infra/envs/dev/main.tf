# Dev Environment - Neo4j GKE Infrastructure
#
# This environment provisions all platform infrastructure for Neo4j deployment:
# - VPC with Cloud NAT for private GKE nodes
# - GKE Autopilot cluster with Workload Identity
# - Service account for Neo4j backups
# - GCS bucket for backup storage
# - Secret Manager secrets for credentials

# VPC Network
module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
  region     = var.region
  vpc_name   = "neo4j-dev-vpc"

  # IP ranges for GKE
  subnet_ip_range   = "10.0.0.0/24"
  pods_ip_range     = "10.1.0.0/16"
  services_ip_range = "10.2.0.0/20"

  # Enable Cloud NAT for private node egress
  enable_cloud_nat = true

  labels = {
    environment = "dev"
    managed_by  = "tofu"
  }
}

# GKE Autopilot Cluster
module "gke" {
  source              = "../../modules/gke"
  project_id          = var.project_id
  region              = var.region
  cluster_name        = "neo4j-dev"
  network_id          = module.vpc.network_id
  subnet_id           = module.vpc.subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  # Dev settings
  deletion_protection = false
  release_channel     = "REGULAR"

  # Maintenance window: weekends
  maintenance_start_time = "2025-01-01T09:00:00Z"
  maintenance_end_time   = "2025-01-01T17:00:00Z"
  maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"

  labels = {
    environment = "dev"
    managed_by  = "tofu"
  }
}

# Backup Service Account
module "backup_sa" {
  source     = "../../modules/service_accounts"
  project_id = var.project_id

  service_accounts = {
    "neo4j-backup" = {
      description  = "Neo4j backup service account for dev environment"
      display_name = "Neo4j Backup SA (Dev)"
    }
  }

  # Dev settings - allow destruction for cleanup
  prevent_destroy_service_accounts = false
}

# Backup Bucket
module "backup_bucket" {
  source          = "../../modules/backup_bucket"
  project_id      = var.project_id
  bucket_name     = "${var.project_id}-neo4j-backups-dev"
  location        = var.region
  backup_sa_email = module.backup_sa.service_accounts["neo4j-backup"].email

  # Retention settings
  backup_retention_days   = 30
  backup_versions_to_keep = 5

  # Dev settings - allow destruction for cleanup
  force_destroy = true

  labels = {
    environment = "dev"
    purpose     = "neo4j-backup"
    managed_by  = "tofu"
  }
}

# Secrets for Neo4j credentials
module "secrets" {
  source     = "../../modules/secrets"
  project_id = var.project_id

  secrets = {
    "neo4j-admin-password-dev" = {
      description = "Neo4j admin password for dev environment"
      labels = {
        environment = "dev"
        application = "neo4j"
      }
    }
  }

  # No accessors defined here - will be granted via Workload Identity in apps layer
}
