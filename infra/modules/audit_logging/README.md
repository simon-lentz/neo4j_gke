# Audit Logging Module

Configures Cloud Audit Logs and creates a GCS bucket for audit log storage.

## Features

- **Cloud Audit Logs** for KMS (DATA_READ/DATA_WRITE operations)
- **Cloud Audit Logs** for GCS (DATA_READ/DATA_WRITE operations)
- **Audit logs bucket** with configurable retention and security hardening

## Usage

```hcl
module "audit_logging" {
  source = "../../modules/audit_logging"

  project_id           = "my-project"
  logs_bucket_location = "US"

  # Optional: disable specific audit types
  enable_kms_audit_logs = true
  enable_gcs_audit_logs = true

  # Optional: customize retention
  log_retention_days = 365

  labels = {
    environment = "production"
  }
}
```

## What Gets Logged

### KMS Audit Logs

When enabled, captures:
- **DATA_READ**: Key metadata lookups, public key retrieval
- **DATA_WRITE**: Encrypt/decrypt operations, key version creation

### GCS Audit Logs

When enabled, captures:
- **DATA_READ**: Object reads, metadata retrieval
- **DATA_WRITE**: Object creates, updates, deletes

Logs are visible in Cloud Logging under `cloudaudit.googleapis.com/data_access`.

## Security Features

| Feature | Setting | Purpose |
|---------|---------|---------|
| UBLA | Enabled | Uniform permissions (no ACLs) |
| PAP | Enforced | Prevent public exposure of logs |
| Lifecycle | Configurable | Auto-delete old logs |
| force_destroy | false | Protect logs from accidental deletion |

## Resources Created

- `google_storage_bucket` - Audit logs bucket
- `google_project_iam_audit_config` - KMS audit config (conditional)
- `google_project_iam_audit_config` - GCS audit config (conditional)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.1 |
| google | ~> 6.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| logs_bucket_location | Location for logs bucket | `string` | `"US"` | no |
| logs_bucket_name | Custom bucket name (auto-generated if null) | `string` | `null` | no |
| enable_kms_audit_logs | Enable KMS DATA_READ/WRITE audit logs | `bool` | `true` | no |
| enable_gcs_audit_logs | Enable GCS DATA_READ/WRITE audit logs | `bool` | `true` | no |
| log_retention_days | Days to retain logs before deletion | `number` | `365` | no |
| labels | Labels for logging resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| logs_bucket_name | Name of the audit logs bucket |
| logs_bucket_url | gs:// URL of the logs bucket |
| logs_bucket_self_link | Self link of the logs bucket |
| kms_audit_logs_enabled | Whether KMS audit logs are enabled |
| gcs_audit_logs_enabled | Whether GCS audit logs are enabled |

## Cost Considerations

Cloud Audit Logs incur costs based on:
- **Log ingestion**: Data Access logs can generate significant volume
- **Log storage**: Retained in Cloud Logging (separate from the GCS bucket)
- **GCS bucket**: Storage costs for the audit logs bucket

To reduce costs, consider:
- Disabling audit types you don't need
- Reducing `log_retention_days`
- Using Cloud Logging exclusion filters for high-volume, low-value events
