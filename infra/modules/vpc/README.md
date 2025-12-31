# VPC Module

Creates a VPC network with a subnet configured for GKE Autopilot, including secondary IP ranges for pods and services, and optional Cloud NAT for egress from private nodes.

## Usage

```hcl
module "vpc" {
  source     = "../../modules/vpc"
  project_id = "my-project"
  region     = "us-central1"
  vpc_name   = "neo4j-vpc"
}
```

## Resources Created

- `google_compute_network` - Custom mode VPC
- `google_compute_subnetwork` - Subnet with secondary ranges for pods/services
- `google_compute_router` - Cloud Router (when Cloud NAT enabled)
- `google_compute_router_nat` - Cloud NAT for private node egress

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.1 |
| google | ~> 6.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project to create VPC resources in | `string` | n/a | yes |
| region | GCP region for regional resources | `string` | n/a | yes |
| vpc_name | Name of the VPC network | `string` | `"neo4j-vpc"` | no |
| subnet_name | Name of the subnet | `string` | `null` (defaults to vpc_name-subnet) | no |
| subnet_ip_range | Primary IP CIDR range for the subnet | `string` | `"10.0.0.0/24"` | no |
| pods_ip_range | Secondary IP CIDR range for GKE pods | `string` | `"10.1.0.0/16"` | no |
| services_ip_range | Secondary IP CIDR range for GKE services | `string` | `"10.2.0.0/20"` | no |
| pods_range_name | Name for the pods secondary range | `string` | `"pods"` | no |
| services_range_name | Name for the services secondary range | `string` | `"services"` | no |
| enable_cloud_nat | Whether to create Cloud NAT | `bool` | `true` | no |
| enable_flow_logs | Enable VPC flow logs on subnet (incurs costs) | `bool` | `true` | no |
| nat_ip_allocate_option | NAT IP allocation: AUTO_ONLY or MANUAL_ONLY | `string` | `"AUTO_ONLY"` | no |
| nat_source_subnetwork_ip_ranges_to_nat | Subnet ranges to NAT | `string` | `"ALL_SUBNETWORKS_ALL_IP_RANGES"` | no |
| labels | Labels to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| network_id | The ID of the VPC network |
| network_name | The name of the VPC network |
| network_self_link | The self_link of the VPC network |
| subnet_id | The ID of the subnet |
| subnet_name | The name of the subnet |
| subnet_self_link | The self_link of the subnet |
| subnet_region | The region of the subnet |
| pods_range_name | The name of the secondary IP range for pods |
| services_range_name | The name of the secondary IP range for services |
| router_name | The name of the Cloud Router (if created) |
| nat_name | The name of the Cloud NAT (if created) |
| nat_external_ip | The external IP of Cloud NAT (if created) |

## Cost Considerations

### VPC Flow Logs

Flow logs are enabled by default (`enable_flow_logs = true`) for security monitoring and troubleshooting. Cost implications:

- **Logging costs**: ~$0.50/GB ingested to Cloud Logging
- **Storage costs**: If exported to GCS via log sink, standard storage rates apply
- **Mitigation**: Subnet configured with 0.5 sampling rate (50% of flows logged)

To disable for cost-sensitive environments:

```hcl
module "vpc" {
  # ...
  enable_flow_logs = false
}
```

### Cloud NAT

Cloud NAT is enabled by default for private GKE node egress. Costs include:

- **Hourly charge**: Per NAT gateway per region
- **Data processing**: Per GB processed through NAT

See [Cloud NAT pricing](https://cloud.google.com/nat/pricing) for current rates.

To disable for environments with public node IPs:

```hcl
module "vpc" {
  # ...
  enable_cloud_nat = false
}
```
