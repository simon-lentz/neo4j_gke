locals {
  required_apis = toset(concat([
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ], var.additional_project_services))

  kms_multi_region_map = {
    "US"   = "us"
    "EU"   = "europe"
    "ASIA" = "asia"
    # Predefined dual regions: KMS supports them directly
    "NAM4" = "nam4"
    "EUR4" = "eur4"
  }

  normalized_bucket_location = upper(var.bucket_location)
  inferred_kms_location = (
    contains(keys(local.kms_multi_region_map), local.normalized_bucket_location)
    ? local.kms_multi_region_map[local.normalized_bucket_location]
    : var.bucket_location
  )

  # Normalize to lowercase for KMS
  ring_location = lower(coalesce(var.kms_location, local.inferred_kms_location))

  computed_ring = coalesce(var.kms_key_ring_name, "${var.project_id}-tfstate-ring")
  computed_bkt  = coalesce(var.bucket_name, "${var.project_id}-state")
}


resource "random_id" "bucket_suffix" {
  count = var.bucket_name == null && var.randomize_bucket_name ? 1 : 0
  # at 3 bytes, this gives us 16M combinations
  # which should be plenty to avoid collisions
  byte_length = 3
}

locals {
  bucket_name = (
    var.bucket_name != null ? var.bucket_name :
    var.randomize_bucket_name ? "${local.computed_bkt}-${random_id.bucket_suffix[0].hex}" :
    local.computed_bkt
  )
}