# Workload Identity Federation (WIF)

## WIF — GitHub & other OIDC IdPs

Provision a hardened Workload Identity Pool + OIDC Provider so external workloads (e.g., GitHub Actions) can mint short-lived Google Cloud credentials—no JSON keys.

## What it creates

- **Workload Identity Pool** (`google_iam_workload_identity_pool`) in `global`.
- **OIDC Provider** (`google_iam_workload_identity_pool_provider`) with:
  - **Issuer** (default GitHub: `https://token.actions.githubusercontent.com`)
  - **Attribute mapping** for claims you can reference in conditions (subject, repository, ref, owner, actor, workflow, sha, event_name, ref_type, aud). You must map any claim [before you can reference it](https://github.com/google-github-actions/auth) in a CEL expression or IAM policy
  - **Attribute condition** (CEL) computed from your selectors (repos, owners, refs). Categories are joined with AND; alternatives within a category use OR. See "Define an attribute condition" in the [WIF docs](https://cloud.google.com/config-connector/docs/reference/resource-docs/iam/iamworkloadidentitypoolprovider).

## Important Notes

### Safety rails

The module supports prevent-destroy for pool/provider. Terraform/OpenTofu doesn't allow variables inside [lifecycle blocks (e.g., prevent_destroy)](https://developer.hashicorp.com/terraform/language/meta-arguments). We implement the "safety rail" by declaring protected and unprotected variants of each resource and selecting one via count. Don't toggle this flag in place on existing resources, treat it as an immutable choice per environment. For further information see [Terraform Variable Validation: Terraform 1.9 & Earlier Versions](https://spacelift.io/blog/terraform-variable-validation).

### Preconditions

You must provide at least one selector (repo, owner, ref, or audience) or set an explicit override. The module enforces this using resource preconditions (evaluated at plan time).

## Inputs (most common)

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | string | — | GCP project for the pool/provider. |
| `pool_id` | string | `github-pool` | Short pool ID. |
| `provider_id` | string | `github-actions` | Short provider ID. |
| `issuer_uri` | string | `https://token.actions.githubusercontent.com` | OIDC issuer (override for GitLab, TFC, Azure DevOps, etc.). |
| `allowed_repositories` | set(string) | `[]` | Allowed repos (`org/repo`). |
| `allowed_repository_owners` | set(string) | `[]` | Optional allowed orgs. |
| `allowed_refs` | list(string) | `[]` | Optional allowed refs (exact `refs/heads/main` or prefix `refs/heads/release/*`). |
| `allowed_audiences` | set(string) | `[]` | Optional OIDC audience filter. |
| `attribute_mapping_extra` | map(string) | `{}` | Extra mappings merged into base. |
| `attribute_condition_override` | string | `null` | Provide a full CEL condition to override all computed conditions. |
| `prevent_destroy_pool` | bool | `true` | Safety rail for prod. |
| `prevent_destroy_provider` | bool | `true` | Safety rail for prod. |

> **Notes:**
>
> - At least one selector (`repositories/owners/refs/audiences`) or `attribute_condition_override` is required.
> - If allowed_audiences is omitted, GCP defaults to requiring the OIDC token's aud to equal the provider's canonical resource name (with or without the HTTPS prefix). Consider setting an explicit audience for non-GitHub issuers.
>

## Outputs

- `pool_name` / `provider_name`: Fully-qualified resource names.
- `principalset_repository`: map `<repo> -> principalSet://.../attribute.repository/<repo>`
- `principalset_owner`: map `<owner> -> principalSet://.../attribute.repository_owner/<owner>`

## Testing

- **`tofu test`** (`./tests/wif.tftest.hcl`) asserts mapping keys and the generated `attribute_condition` (repo ORs, ref exact/prefix, audience).
- **Terratest** (`infrastructure/test/wif_test.go`) applies in a test project (with `prevent_destroy_* = false`), describes the provider via `gcloud`, and asserts issuer + attribute condition.

## Design notes

- Combine categories with `AND` (repo `AND` ref `AND` audience) and `OR` within a category. This narrows the trust as recommended.
- Grant `roles/iam.workloadIdentityUser` on the service account to the principalSet output, then use `google-github-actions/auth` to impersonate that service account in CI.
