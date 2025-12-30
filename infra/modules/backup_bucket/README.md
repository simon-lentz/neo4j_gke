# Backup Bucket Module

Creates a GCS bucket for Neo4j backups with security best practices:
- Uniform Bucket-Level Access (UBLA) enabled
- Public Access Prevention (PAP) enforced
- Object versioning for recovery
- Lifecycle rules for retention management
- Least-privilege IAM for backup service account

## Usage

```hcl
module "backup_bucket" {
  source          = "../../modules/backup_bucket"
  project_id      = "my-project"
  bucket_name     = "my-project-neo4j-backups"
  location        = "us-central1"
  backup_sa_email = module.backup_sa.service_accounts["neo4j-backup"].email

  backup_retention_days   = 30  # Auto-delete after 30 days
  backup_versions_to_keep = 5   # Keep 5 old versions
  force_destroy           = false  # Protect from accidental deletion

  labels = {
    environment = "production"
    purpose     = "neo4j-backup"
  }
}
```

## Security Features

| Feature | Setting | Purpose |
|---------|---------|---------|
| UBLA | Enabled | Uniform permissions (no ACLs) |
| PAP | Enforced | Prevent accidental public exposure |
| Versioning | Enabled | Recover deleted/overwritten files |
| IAM | objectCreator + objectViewer | Least-privilege for backup SA |

## Backup Service Account Permissions

The module grants the backup service account:
- `roles/storage.objectCreator` - Create backup files
- `roles/storage.objectViewer` - Verify backup files exist

This follows least-privilege: the SA cannot delete objects, list other buckets, or modify bucket settings.

## Resources Created

- `google_storage_bucket` - Backup bucket
- `google_storage_bucket_iam_member` - objectCreator binding
- `google_storage_bucket_iam_member` - objectViewer binding

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.1 |
| google | ~> 6.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project for the bucket | `string` | n/a | yes |
| bucket_name | Globally unique bucket name | `string` | n/a | yes |
| location | GCS location | `string` | n/a | yes |
| backup_sa_email | Service account email for backups | `string` | n/a | yes |
| storage_class | Storage class | `string` | `"STANDARD"` | no |
| backup_retention_days | Days to retain backups (0 = forever) | `number` | `30` | no |
| backup_versions_to_keep | Noncurrent versions to keep | `number` | `5` | no |
| force_destroy | Allow destruction with objects | `bool` | `false` | no |
| enable_versioning | Enable object versioning | `bool` | `true` | no |
| labels | Labels for the bucket | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the backup bucket |
| bucket_url | gs:// URL of the bucket |
| bucket_self_link | Self link of the bucket |
| bucket_location | Location of the bucket |
