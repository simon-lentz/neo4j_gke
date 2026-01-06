# E2E Test Providers
# Configures providers with direct variable inputs for test isolation

provider "google" {
  project = var.project_id
  region  = var.region
}

# Get current GCP client config for authentication
data "google_client_config" "default" {}

# Fetch GKE cluster information using direct variables
data "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.cluster_location
  project  = var.project_id
}

# Kubernetes provider configured with GKE cluster credentials
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.this.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

# Helm provider configured with GKE cluster credentials
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.this.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
  }
}
