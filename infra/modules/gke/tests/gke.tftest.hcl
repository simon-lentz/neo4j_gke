# GKE Autopilot module tests covering 'plan' scenarios.
# See gke_test.go for 'apply' scenarios (slow - creates real clusters).

run "plan_autopilot_cluster" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.enable_autopilot == true
    error_message = "Cluster should be Autopilot mode."
  }

  assert {
    condition     = google_container_cluster.autopilot.location == "us-central1"
    error_message = "Cluster should be regional."
  }
}

run "plan_private_nodes" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.private_cluster_config[0].enable_private_nodes == true
    error_message = "Private nodes should be enabled."
  }

  assert {
    condition     = google_container_cluster.autopilot.private_cluster_config[0].enable_private_endpoint == false
    error_message = "Private endpoint should be disabled by default."
  }

  assert {
    condition     = google_container_cluster.autopilot.private_cluster_config[0].master_ipv4_cidr_block == "172.16.0.0/28"
    error_message = "Master CIDR should use default value."
  }
}

run "plan_custom_master_cidr" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    master_ipv4_cidr     = "192.168.0.0/28"
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.private_cluster_config[0].master_ipv4_cidr_block == "192.168.0.0/28"
    error_message = "Master CIDR should use custom value."
  }
}

run "plan_release_channel" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    release_channel      = "STABLE"
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.release_channel[0].channel == "STABLE"
    error_message = "Release channel should be STABLE."
  }
}

run "plan_maintenance_window" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    network_id             = "projects/test-project/global/networks/test-vpc"
    subnet_id              = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name        = "pods"
    services_range_name    = "services"
    maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SU"
    enable_container_api   = false
  }

  assert {
    condition     = google_container_cluster.autopilot.maintenance_policy[0].recurring_window[0].recurrence == "FREQ=WEEKLY;BYDAY=SU"
    error_message = "Maintenance recurrence should be customizable."
  }
}

run "plan_deletion_protection" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    deletion_protection  = true
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.deletion_protection == true
    error_message = "Deletion protection should be enabled."
  }
}

run "plan_deletion_protection_disabled" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    deletion_protection  = false
    enable_container_api = false
  }

  assert {
    condition     = google_container_cluster.autopilot.deletion_protection == false
    error_message = "Deletion protection should be disabled for dev."
  }
}

run "plan_enable_container_api" {
  command = plan

  variables {
    project_id           = "test-project"
    region               = "us-central1"
    network_id           = "projects/test-project/global/networks/test-vpc"
    subnet_id            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    pods_range_name      = "pods"
    services_range_name  = "services"
    enable_container_api = true
  }

  assert {
    condition     = length(google_project_service.container) == 1
    error_message = "Should enable Container API."
  }

  assert {
    condition     = google_project_service.container[0].service == "container.googleapis.com"
    error_message = "Should enable container.googleapis.com."
  }
}
