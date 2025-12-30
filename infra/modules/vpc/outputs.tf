output "network_id" {
  description = "The ID of the VPC network."
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "The self_link of the VPC network."
  value       = google_compute_network.vpc.self_link
}

output "subnet_id" {
  description = "The ID of the subnet."
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "The name of the subnet."
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "The self_link of the subnet."
  value       = google_compute_subnetwork.subnet.self_link
}

output "subnet_region" {
  description = "The region of the subnet."
  value       = google_compute_subnetwork.subnet.region
}

output "pods_range_name" {
  description = "The name of the secondary IP range for pods."
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "The name of the secondary IP range for services."
  value       = var.services_range_name
}

output "router_name" {
  description = "The name of the Cloud Router (if created)."
  value       = var.enable_cloud_nat ? google_compute_router.router[0].name : null
}

output "nat_name" {
  description = "The name of the Cloud NAT (if created)."
  value       = var.enable_cloud_nat ? google_compute_router_nat.nat[0].name : null
}
