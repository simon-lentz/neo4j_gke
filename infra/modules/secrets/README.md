# Secrets Module

Creates Secret Manager secrets with optional IAM bindings for accessor roles.

## Usage

```hcl
module "secrets" {
  source     = "../../modules/secrets"
  project_id = "my-project"

  secrets = {
    "neo4j-admin-password" = {
      description = "Neo4j admin password"
      labels      = { environment = "dev" }
    }
    "api-key" = {
      description = "External API key"
      replication = "user_managed"
    }
  }

  accessors = {
    "neo4j-admin-password" = [
      "serviceAccount:neo4j@my-project.iam.gserviceaccount.com"
    ]
  }
}
```

## Important Notes

- This module creates empty secrets. You must add secret versions separately (manually or via another resource).
- For sensitive values, use `google_secret_manager_secret_version` with the `secret_data` attribute.

## Resources Created

- `google_project_service` - Enables Secret Manager API (optional)
- `google_secret_manager_secret` - Secret containers
- `google_secret_manager_secret_iam_member` - IAM bindings for accessors

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.1 |
| google | ~> 6.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project to create secrets in | `string` | n/a | yes |
| secrets | Map of secret configurations | `map(object({...}))` | `{}` | no |
| accessors | Map of secret-key to IAM members for accessor role | `map(list(string))` | `{}` | no |
| replication_locations | Locations for user_managed replication | `list(string)` | `["us-central1", "us-east1"]` | no |
| enable_secret_manager_api | Whether to enable Secret Manager API | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| secrets | Map of secret details (id, name, secret_id) |
| secret_ids | Map of secret-key to secret_id |
| secret_names | Map of secret-key to full resource name |
