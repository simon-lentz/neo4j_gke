output "cluster_id" {
  description = "The unique identifier of the GKE cluster."
  value       = google_container_cluster.autopilot.id
}

output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.autopilot.name
}

output "cluster_location" {
  description = "The location (region) of the GKE cluster."
  value       = google_container_cluster.autopilot.location
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master."
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate of the cluster CA."
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster (project_id.svc.id.goog)."
  value       = "${var.project_id}.svc.id.goog"
}

output "cluster_self_link" {
  description = "The self_link of the GKE cluster."
  value       = google_container_cluster.autopilot.self_link
}

output "master_version" {
  description = "The current version of the master in the cluster."
  value       = google_container_cluster.autopilot.master_version
}
