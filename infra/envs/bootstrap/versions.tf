terraform {
  required_version = "~> 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.3"
    }
  }

  # GCS backend for remote state storage.
  # First apply uses -backend=false (bucket doesn't exist yet).
  # After bucket creation, run: tofu init -backend-config="bucket=<BUCKET>" -backend-config="prefix=bootstrap" -migrate-state
  backend "gcs" {}
}