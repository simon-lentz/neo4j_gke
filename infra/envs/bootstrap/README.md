# Bootstrap Environment

## OpenTofu GCS Backend Bootstrap (GCP + CMEK)

This environment configuration bootstraps a hardened Google Cloud Storage (GCS) backend for OpenTofu/Terraform with customer-managed encryption keys (CMEK) and safe defaults.

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
  Enables the minimal project services (Storage, KMS, IAM, Service Usage) up front to avoid "API not enabled" races.
- **Backend snippet output**
  We output a ready-to-paste object as `backend` with a `config` map (`bucket`, `prefix`) you can drop into your root backend block.

### Location compatibility

- `bucket_location` accepts region, dual-region code, or multi-region (e.g., `us-central1`, `NAM4`, `US`).
- If `kms_location` is omitted, a compatible KMS location is inferred:
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

### **Bootstrap (two-step process)**

This is a two-step process because the GCS bucket doesn't exist yet when we first apply. We create resources with local state, then migrate to GCS.

#### Step 1: Create the state bucket

```bash
cd infra/envs/bootstrap
tofu init

# Apply with local state (bucket doesn't exist yet)
tofu apply \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION"
# kms_location is optional -> the module infers compatible values:
#   US->us, EU->europe, ASIA->asia, NAM4->nam4, EUR4->eur4
```

Note the `state.bucket_name` from the output (e.g., `your-project-id-state`).

#### Step 2: Migrate state to GCS

```bash
# Replace YOUR_STATE_BUCKET with the bucket name from step 1
tofu init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="prefix=bootstrap" \
  -migrate-state -force-copy
```

This migrates the local state to GCS so other layers (dev, apps) can read the bootstrap outputs via `terraform_remote_state`.

> **Verify migration**:
>
> ```bash
> # Confirm state is in GCS
> gcloud storage cat "gs://YOUR_STATE_BUCKET/bootstrap/default.tfstate" | jq '.outputs | keys'
> # Should output: ["backend", "state"]
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

Use these presets in **Step 1** of the bootstrap process. Remember to run **Step 2** (state migration) after apply.

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

### Importing existing resources

If you've previously created KMS resources (e.g., from a partial apply), import them before re-applying:

```bash
# Import existing KMS key ring
tofu import \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION" \
  google_kms_key_ring.state_ring \
  "projects/$PROJECT_ID/locations/$BUCKET_LOCATION/keyRings/$PROJECT_ID-tfstate-ring"

# Import existing KMS crypto key
tofu import \
  -var="project_id=$PROJECT_ID" \
  -var="bucket_location=$BUCKET_LOCATION" \
  google_kms_crypto_key.state_key \
  "projects/$PROJECT_ID/locations/$BUCKET_LOCATION/keyRings/$PROJECT_ID-tfstate-ring/cryptoKeys/tfstate-key"
```

### Remote state has no outputs

If downstream layers fail with `outputs is object with no attributes`, the bootstrap state wasn't migrated to GCS. Run Step 2 (state migration) from the bootstrap directory:

```bash
cd infra/envs/bootstrap
tofu init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="prefix=bootstrap" \
  -migrate-state -force-copy
```
