# Google provider for GCP resources
provider "google" {
  project = var.project_id
  region  = var.region
}

# Get current GCP client config for authentication
data "google_client_config" "default" {}

# Fetch GKE cluster information from platform layer
data "google_container_cluster" "this" {
  name     = data.terraform_remote_state.platform.outputs.cluster_name
  location = data.terraform_remote_state.platform.outputs.cluster_location
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
