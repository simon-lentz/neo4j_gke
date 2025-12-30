# Service Accounts

## Service Accounts — minimal, policy-compliant provisioning

Create one or more Google Cloud **service accounts** with strict, deterministic IDs and metadata.
This module does not grant any IAM Compose IAM at a higher level (e.g., your env roots) to keep policy close to the environment and avoid application-specific coupling.

---

## What it creates

* **Service accounts** (`google_service_account`) — one per entry in `service_accounts`

  * `display_name` defaults to `description`
  * Optional `disabled = true` (account is created then disabled)
* **Deterministic IDs**:

  * ID candidate = `lowercase(sanitize(sa_prefix + key + sa_suffix))`
  * Must meet IAM constraints (6–30 chars; starts with a letter; ends with letter/digit; only `[a-z0-9-]`)
  * If the candidate is invalid/too long/short → fallback to `sa-<27hex>` (exactly 30 chars)
  * Optional **stable 6-hex hash suffix** via `id_hash_suffix_from` to reduce accidental collisions
* **Safety rail**: `prevent_destroy_service_accounts` (default **true**) uses a protected/unprotected resource variant pattern so you can opt into deletion safety in prod

> **Scope & composition:**
>
> * Grant **Workload Identity Federation (WIF)** impersonation (e.g., `roles/iam.workloadIdentityUser` to a `principalSet://…`) **outside** this module—typically using your WIF outputs.
> * Grant **project** / **bucket** / **secret** roles in environment roots where policy belongs.

---

## Inputs (most common)

| Name                               | Type           | Default | Description                                                                                               |
| ---------------------------------- | -------------- | ------- | --------------------------------------------------------------------------------------------------------- |
| `project_id`                       | string         | —       | GCP project where SAs are created.                                                                        |
| `service_accounts`                 | map(object)    | `{}`    | Map `key → { description (req), display_name (opt), disabled (opt=false) }`.                              |
| `sa_prefix`                        | string         | `""`    | Optional prefix for the **account\_id** (sanitized to `[a-z0-9-]`).                                       |
| `sa_suffix`                        | string         | `""`    | Optional suffix for the **account\_id** (sanitized).                                                      |
| `id_hash_suffix_from`              | string \| null | `null`  | If set, append `-<6hex>` derived from this stable seed to the ID (deterministic; not a security feature). |
| `prevent_destroy_service_accounts` | bool           | `true`  | Prevent accidental destroy (recommended for prod).                                                        |

> **ID tips:** Keep `sa_prefix + key + sa_suffix (+ -<6hex>) ≤ 30` chars. If not, the module automatically uses the `sa-<27hex>` fallback.

---

## Outputs

* `service_accounts` — map `key → { email, account_id, name, unique_id }`

---

## Example

```hcl
module "service_accounts" {
  source     = "../../modules/service_accounts"
  project_id = var.project_id

  sa_prefix = "gha-"                # keep it short to stay under 30 chars
  id_hash_suffix_from = "dev"       # optional, yields deterministic -<6hex>

  service_accounts = {
    "plan" = {
      description = "CI plan service account"
      # display_name omitted -> defaults to description
    }
    "apply" = {
      description = "CI apply service account"
      disabled    = false
    }
  }
}
```

> **IMPORTANT: Grant IAM outside this module**

---

## Testing

* **Plan-phase**: `./tests/service_accounts.tftest.hcl` validates:

  * protected/unprotected variant selection
  * ID construction (prefix/suffix, 6-hex suffix, fallback hashing)
  * `display_name` defaulting and `disabled` flag
* **Integration**: `infrastructure/test/service_accounts_test.go` applies in a test project, describes the SA via `gcloud`, asserts the `disabled` state, and destroys (with `prevent_destroy_service_accounts=false`).

---

## Notes & caveats

* **Prevent-destroy toggle**: Treat `prevent_destroy_service_accounts` as an **environment-level choice**. Do not flip it on long-lived resources; if you must change it, plan a state move/import rather than in-place toggle.
* **No API enablement here**: enable required APIs at the platform/bootstrap layer to keep module scope tight.
* **No keys** are created by this module. Prefer **keyless** access (WIF + SA impersonation). If you must create keys, do so explicitly in a tightly controlled root and rotate regularly.
