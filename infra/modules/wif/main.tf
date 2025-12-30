provider "google" {
  project = var.project_id
}

# ---- pool (two variants) ----
resource "google_iam_workload_identity_pool" "pool_protected" {
  count                     = var.prevent_destroy_pool ? 1 : 0
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "WIF Pool"
  description               = "Workload Identity Federation pool"

  lifecycle { prevent_destroy = true }
}

resource "google_iam_workload_identity_pool" "pool_unprotected" {
  count                     = var.prevent_destroy_pool ? 0 : 1
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "WIF Pool"
  description               = "Workload Identity Federation pool"
}

# Convenience locals for whichever variant exists
locals {
  _pool = var.prevent_destroy_pool ? google_iam_workload_identity_pool.pool_protected[0] : google_iam_workload_identity_pool.pool_unprotected[0]

  # Avoid coalesce() error when both are empty. Let resource preconditions fire instead.
  effective_attribute_condition = trimspace(join("", compact([
    var.attribute_condition_override,
    local.computed_attribute_condition,
  ])))
}


# ---- provider (two variants) ----
resource "google_iam_workload_identity_pool_provider" "provider_protected" {
  count                              = var.prevent_destroy_provider ? 1 : 0
  project                            = var.project_id
  workload_identity_pool_id          = local._pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id

  display_name = "OIDC Provider"
  description  = "Trusted issuer: ${var.issuer_uri}"

  oidc {
    issuer_uri        = var.issuer_uri
    allowed_audiences = tolist(var.allowed_audiences)
  }

  attribute_mapping   = merge(local.base_attribute_mapping, var.attribute_mapping_extra)
  attribute_condition = local.effective_attribute_condition

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = local.effective_attribute_condition != ""
      error_message = "You must specify at least one selector (repositories/owners/refs/audiences) or set attribute_condition_override."
    }
  }
}

resource "google_iam_workload_identity_pool_provider" "provider_unprotected" {
  count                              = var.prevent_destroy_provider ? 0 : 1
  project                            = var.project_id
  workload_identity_pool_id          = local._pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id

  display_name = "OIDC Provider"
  description  = "Trusted issuer: ${var.issuer_uri}"

  oidc {
    issuer_uri        = var.issuer_uri
    allowed_audiences = tolist(var.allowed_audiences)
  }

  attribute_mapping   = merge(local.base_attribute_mapping, var.attribute_mapping_extra)
  attribute_condition = local.effective_attribute_condition

  lifecycle {
    precondition {
      condition     = local.effective_attribute_condition != ""
      error_message = "You must specify at least one selector (repositories/owners/refs/audiences) or set attribute_condition_override."
    }
  }
}

locals {
  _provider = var.prevent_destroy_provider ? google_iam_workload_identity_pool_provider.provider_protected[0] : google_iam_workload_identity_pool_provider.provider_unprotected[0]
}