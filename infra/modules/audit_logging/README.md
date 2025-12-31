# Audit Logging Module

Configures Cloud Audit Logs and creates a GCS bucket for audit log storage.

## Features

- **Cloud Audit Logs** for KMS (DATA_READ/DATA_WRITE operations)
- **Cloud Audit Logs** for GCS (DATA_READ/DATA_WRITE operations)
- **Audit logs bucket** with configurable retention and security hardening
- **Cloud Logging sink** to route audit logs from Cloud Logging to GCS (optional)
- **GCS access logging** for target buckets like state bucket (optional)

## Usage

```hcl
module "audit_logging" {
  source = "../../modules/audit_logging"

  project_id           = "my-project"
  logs_bucket_location = "US"

  # Optional: disable specific audit types
  enable_kms_audit_logs = true
  enable_gcs_audit_logs = true

  # Optional: enable log sink to route logs to GCS
  enable_log_sink = true

  # Optional: enable access logging on state bucket
  enable_gcs_access_logging = true
  state_bucket_name         = "my-project-tf-state"

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

## Log Sink Configuration

When `enable_log_sink = true`, a Cloud Logging sink routes audit logs from Cloud Logging to the GCS bucket. This provides:

- **Long-term retention**: Logs stored in GCS beyond Cloud Logging retention limits
- **Cost efficiency**: GCS storage is cheaper than Cloud Logging for long-term archival
- **Export compliance**: Audit logs available for external SIEM/compliance tools

The sink captures logs matching:
- `protoPayload.serviceName="cloudkms.googleapis.com"` (KMS operations)
- `protoPayload.serviceName="storage.googleapis.com"` (GCS operations)
- `protoPayload.serviceName="container.googleapis.com"` (GKE operations)

## GCS Access Logging

When `enable_gcs_access_logging = true` and `state_bucket_name` is provided, creates a separate bucket to store access logs for the target bucket. This captures:

- Every object read/write to the target bucket
- Requester identity and IP address
- Request/response details

Useful for auditing access to sensitive buckets like Terraform state.

## Security Features

| Feature | Setting | Purpose |
|---------|---------|---------|
| UBLA | Enabled | Uniform permissions (no ACLs) |
| PAP | Enforced | Prevent public exposure of logs |
| Lifecycle | Configurable | Auto-delete old logs |
| force_destroy | false | Protect logs from accidental deletion |

## Resources Created

- `google_storage_bucket.logs` - Audit logs bucket (always created)
- `google_project_iam_audit_config.kms_audit` - KMS audit config (when `enable_kms_audit_logs = true`)
- `google_project_iam_audit_config.gcs_audit` - GCS audit config (when `enable_gcs_audit_logs = true`)
- `google_logging_project_sink.audit_sink` - Cloud Logging sink (when `enable_log_sink = true`)
- `google_storage_bucket_iam_member.sink_writer` - Sink IAM binding (when `enable_log_sink = true`)
- `google_storage_bucket.target_access_logs` - Access logs bucket (when `enable_gcs_access_logging = true` and `state_bucket_name` provided)

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
| enable_log_sink | Create Cloud Logging sink to route audit logs to GCS | `bool` | `true` | no |
| enable_gcs_access_logging | Enable GCS access logging on target bucket | `bool` | `true` | no |
| state_bucket_name | Target bucket for access logging (null skips access logging) | `string` | `null` | no |
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
| log_sink_name | Name of the Cloud Logging sink (empty if disabled) |
| log_sink_writer_identity | Service account identity used by the sink |
| access_logs_bucket_name | Name of the access logs bucket (empty if disabled) |

## Cost Considerations

Cloud Audit Logs incur costs based on:
- **Log ingestion**: Data Access logs can generate significant volume
- **Log storage**: Retained in Cloud Logging (separate from the GCS bucket)
- **GCS bucket**: Storage costs for the audit logs bucket

To reduce costs, consider:
- Disabling audit types you don't need
- Reducing `log_retention_days`
- Using Cloud Logging exclusion filters for high-volume, low-value events
