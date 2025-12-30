# IaC Bootstrap

## OpenTofu GCS Backend Bootstrap (GCP + CMEK)

This module bootstraps a hardened Google Cloud Storage (GCS) backend for OpenTofu/Terraform with customer-managed encryption keys (CMEK) and safe defaults.

---

## What it creates

- **KMS key ring + crypto key (CMEK)**
  - The bucket uses this CMEK as its default encryption key. Only the GCS service agent is granted `roles/cloudkms.cryptoKeyEncrypterDecrypter`, so callers do not need KMS permissions to read/write state. This isolates encryption to the service plane and keeps IAM simple.
  - `kms_protection_level` can be `SOFTWARE` (default) or `HSM`. `EXTERNAL` / `EXTERNAL_VPC` are for Cloud EKM scenarios and typically require additional setup.
- **Hardened GCS bucket**
  - UBLA = true (Uniform Bucket-Level Access): IAM only, no ACL foot-guns.
  - PAP = enforced (Public Access Prevention): blocks public exposure.
  - Default encryption = CMEK (the key above).
  - Versioning = configurable (default off to keep CI ephemeral. Recommended on for prod).
  - Optional retention policy: enforce minimum object age before deletion (off by default).
  - Soft delete policy: explicitly configurable. Soft delete is enabled by default by GCS (7 days) unless overridden. Use `soft_delete_retention_seconds = 0` to disable for CI, or set a duration for prod.
- **Enabled APIs**
  The module enables the minimal project services (Storage, KMS, IAM, Service Usage) up front to avoid "API not enabled" races.
- **Backend snippet output**
  We output a ready-to-paste object as `backend` with a `config` map (`bucket`, `prefix`) you can drop into your root backend block.

### Location compatibility

- `bucket_location` accepts region, dual-region code, or multi-region (e.g., `us-central1`, `NAM4`, `US`).
- If `kms_location` is omitted, the module infers a compatible KMS location:
  - `US` -> `us`, `EU` -> `europe`, `ASIA` -> `asia`
  - `NAM4` -> `nam4`, `EUR4` -> `eur4`
  - For regional buckets, the same region is used.
- CMEK integrations require keys to be in a compatible location with the protected resource.

---

## Quick start (local workstation)

Requirements: `gcloud` CLI authenticated, OpenTofu/Terraform (>= 1.9.1), and permissions to create KMS + GCS.

### **Configure ADC**

```bash
export PROJECT_ID="your-gcp-project-id"
export BUCKET_LOCATION="us-central1"   # or NAM4 / US, etc.

gcloud config set project "$PROJECT_ID"
gcloud auth application-default login
# Optional: avoid quota warnings for user ADC:
gcloud auth application-default set-quota-project "$PROJECT_ID"
```

### **Apply the bootstrap module**

```bash
cd infrastructure/iac/modules/bootstrap
tofu init

# Minimal example (keys co-located)
tofu apply \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION"
# kms_location is optional -> the module infers compatible values:
#   US->us, EU->europe, ASIA->asia, NAM4->nam4, EUR4->eur4
```

> **On success**:
>
> ```hcl
> terraform {
>   backend "gcs" {
>     bucket = "<output.backend.config.bucket>"
>     prefix = "<output.backend.config.prefix>"
>   }
> }
> ```
>

### **Verify CMEK**

```bash
# Bucket default key:
gcloud storage buckets describe gs://<bucket> --format="default(default_kms_key)"
# A test object's encryption key:
gcloud storage objects describe gs://<bucket>/<object> --format="default(kms_key)"
```

> **Note**: These should both point at the same KMS key id.

---

## Recommended presets

### Ephemeral / CI

```bash
tofu apply \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION" \
  -var="bucket_versioning=false" \
  -var="retention_period_seconds=null" \
  -var="soft_delete_retention_seconds=0" \
  -var="force_destroy=true" \
  -var='labels={component="bootstrap",env="ci"}'
```

### Production-hardened

```bash
tofu apply \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION" \
  -var="bucket_versioning=true" \
  -var="retention_period_seconds=2592000" \      # 30d
  -var="rotation_period=2592000" \               # 30d
  -var="soft_delete_retention_seconds=604800" \  # 7d (or your policy)
  -var='labels={component="bootstrap",env="prod"}'
```

---

## CI notes (WIF / service accounts)

Authenticate via Workload Identity Federation (WIF) and grant `roles/storage.objectAdmin` on the state bucket to plan/apply SAs to allow the backend to lock/write state. Bucket default CMEK handles encryption so callers don't need KMS IAM.

---

## Troubleshooting

- **CMEK permission denied on bucket create:** ensure the KMS grant to the GCS service agent exists, note that project API enablement can have short propagation delays.
- **Can't delete objects:** check versioning, retention policy, soft delete window, and holds.
- **Dual/Multi-region CMEK:** use the above inference or explicitly set `kms_location` to the compatible region/dual-region.
