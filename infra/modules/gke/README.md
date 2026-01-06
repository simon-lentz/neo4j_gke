# GKE Autopilot Module

Creates a GKE Autopilot cluster with private nodes, Workload Identity, and configurable maintenance windows.

## Usage

```hcl
module "gke" {
  source              = "../../modules/gke"
  project_id          = "my-project"
  region              = "us-central1"
  cluster_name        = "neo4j-cluster"
  network_id          = module.vpc.network_id
  subnet_id           = module.vpc.subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  deletion_protection = false  # Set to true for production
}
```

## Features

- **Autopilot Mode**: Fully managed node provisioning and scaling
- **Private Nodes**: Nodes have internal IPs only (egress via Cloud NAT)
- **Workload Identity**: Automatic identity federation for pods
- **Release Channels**: RAPID, REGULAR, or STABLE update tracks
- **Maintenance Windows**: Configurable maintenance schedules

## Control Plane Access

By default, this module creates a cluster with:

- **Private nodes**: Worker nodes have no public IPs (egress via Cloud NAT)
- **Public control plane**: The Kubernetes API endpoint is publicly accessible

This default is intentional for dev/POC convenience, allowing `kubectl` access without VPN or bastion setup.

### Production Hardening

For production deployments, restrict control plane access using one of these approaches:

**Option 1: Fully private endpoint** (requires VPN/bastion for kubectl access)

```hcl
module "gke" {
  # ...
  enable_private_endpoint = true
}
```

**Option 2: Restrict to specific networks** (allows public access from trusted IPs only)

```hcl
module "gke" {
  # ...
  master_authorized_networks = [
    { cidr_block = "203.0.113.0/24", display_name = "Office network" },
    { cidr_block = "198.51.100.5/32", display_name = "CI/CD runner" },
  ]
}
```

## Workload Identity

The cluster automatically enables Workload Identity. To bind a Kubernetes service account to a GCP service account:

```hcl
# In your application Terraform
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.my_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.gke.workload_identity_pool}[NAMESPACE/KSA_NAME]"
}
```

## Resources Created

- `google_project_service` - Enables Container API (optional)
- `google_container_cluster` - GKE Autopilot cluster

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.1 |
| google | ~> 6.3 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| project_id | GCP project for the cluster | `string` | n/a | yes |
| region | GCP region for the cluster | `string` | n/a | yes |
| cluster_name | Name of the GKE cluster | `string` | `"neo4j-cluster"` | no |
| network_id | VPC network ID | `string` | n/a | yes |
| subnet_id | Subnet ID | `string` | n/a | yes |
| pods_range_name | Secondary range name for pods | `string` | n/a | yes |
| services_range_name | Secondary range name for services | `string` | n/a | yes |
| master_ipv4_cidr | CIDR for master network (/28) | `string` | `"172.16.0.0/28"` | no |
| enable_private_endpoint | Use internal IP as cluster endpoint | `bool` | `false` | no |
| master_authorized_networks | CIDR blocks for master access | `list(object({...}))` | `[]` | no |
| release_channel | GKE release channel | `string` | `"REGULAR"` | no |
| maintenance_start_time | Maintenance window start (RFC3339) | `string` | `"2025-01-01T09:00:00Z"` | no |
| maintenance_end_time | Maintenance window end (RFC3339) | `string` | `"2025-01-01T17:00:00Z"` | no |
| maintenance_recurrence | Maintenance RRULE | `string` | `"FREQ=WEEKLY;BYDAY=SA,SU"` | no |
| deletion_protection | Enable deletion protection | `bool` | `true` | no |
| enable_container_api | Enable Container API | `bool` | `true` | no |
| labels | Labels for the cluster | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster_id | Unique identifier of the cluster |
| cluster_name | Name of the cluster |
| cluster_location | Region of the cluster |
| cluster_endpoint | IP address of the cluster master (sensitive) |
| cluster_ca_certificate | Base64 cluster CA certificate (sensitive) |
| workload_identity_pool | Workload Identity pool (project_id.svc.id.goog) |
| cluster_self_link | Self link of the cluster |
| master_version | Current master version |
