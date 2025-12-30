# VPC module tests covering 'plan' scenarios.
# See vpc_test.go for 'apply' scenarios.

run "plan_basic_vpc" {
  command = plan

  variables {
    project_id = "test-project"
    region     = "us-central1"
  }

  assert {
    condition     = google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "VPC should use custom subnet mode."
  }

  assert {
    condition     = google_compute_network.vpc.routing_mode == "REGIONAL"
    error_message = "VPC should use regional routing mode."
  }

  assert {
    condition     = length(google_compute_subnetwork.subnet.secondary_ip_range) == 2
    error_message = "Subnet should have 2 secondary ranges (pods + services)."
  }

  assert {
    condition     = google_compute_subnetwork.subnet.private_ip_google_access == true
    error_message = "Private Google Access should be enabled."
  }
}

run "plan_custom_ranges" {
  command = plan

  variables {
    project_id        = "test-project"
    region            = "us-central1"
    vpc_name          = "custom-vpc"
    subnet_ip_range   = "10.100.0.0/24"
    pods_ip_range     = "10.200.0.0/16"
    services_ip_range = "10.201.0.0/20"
  }

  assert {
    condition     = google_compute_subnetwork.subnet.ip_cidr_range == "10.100.0.0/24"
    error_message = "Subnet should use custom IP range."
  }

  assert {
    condition     = google_compute_subnetwork.subnet.secondary_ip_range[0].ip_cidr_range == "10.200.0.0/16"
    error_message = "Pods range should use custom IP range."
  }

  assert {
    condition     = google_compute_subnetwork.subnet.secondary_ip_range[1].ip_cidr_range == "10.201.0.0/20"
    error_message = "Services range should use custom IP range."
  }
}

run "plan_with_cloud_nat" {
  command = plan

  variables {
    project_id       = "test-project"
    region           = "us-central1"
    enable_cloud_nat = true
  }

  assert {
    condition     = length(google_compute_router.router) == 1
    error_message = "Cloud Router should be created when NAT is enabled."
  }

  assert {
    condition     = length(google_compute_router_nat.nat) == 1
    error_message = "Cloud NAT should be created when NAT is enabled."
  }

  assert {
    condition     = google_compute_router_nat.nat[0].nat_ip_allocate_option == "AUTO_ONLY"
    error_message = "Cloud NAT should use AUTO_ONLY by default."
  }
}

run "plan_without_cloud_nat" {
  command = plan

  variables {
    project_id       = "test-project"
    region           = "us-central1"
    enable_cloud_nat = false
  }

  assert {
    condition     = length(google_compute_router.router) == 0
    error_message = "Cloud Router should not be created when NAT is disabled."
  }

  assert {
    condition     = length(google_compute_router_nat.nat) == 0
    error_message = "Cloud NAT should not be created when NAT is disabled."
  }
}

run "plan_custom_subnet_name" {
  command = plan

  variables {
    project_id  = "test-project"
    region      = "us-central1"
    vpc_name    = "my-vpc"
    subnet_name = "my-custom-subnet"
  }

  assert {
    condition     = google_compute_subnetwork.subnet.name == "my-custom-subnet"
    error_message = "Subnet should use custom name when provided."
  }
}

run "plan_default_subnet_name" {
  command = plan

  variables {
    project_id = "test-project"
    region     = "us-central1"
    vpc_name   = "my-vpc"
  }

  assert {
    condition     = google_compute_subnetwork.subnet.name == "my-vpc-subnet"
    error_message = "Subnet should default to vpc_name-subnet."
  }
}
