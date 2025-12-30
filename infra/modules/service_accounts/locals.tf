locals {
  # Allowed characters for service-account IDs.
  _alpha_chars  = "abcdefghijklmnopqrstuvwxyz"
  alpha_list    = [for i in range(length(local._alpha_chars)) : substr(local._alpha_chars, i, 1)]
  digit_list    = [for i in range(10) : tostring(i)]
  allowed_chars = concat(local.alpha_list, local.digit_list, ["-"])
  alnum_chars   = concat(local.alpha_list, local.digit_list)

  # Base strings built from prefix + key + suffix, lowercased and sanitised.
  raw_inputs = {
    for key in keys(var.service_accounts) :
    key => lower("${var.sa_prefix}${key}${var.sa_suffix}")
  }

  primary_ids = {
    for key, raw in local.raw_inputs :
    key => trim(join("", [
      for idx in range(length(raw)) : (
        contains(local.allowed_chars, substr(raw, idx, 1))
        ? substr(raw, idx, 1)
        : "-"
      )
    ]), "-")
  }

  # Optional 6-hex hash suffix derived from a stable seed
  hash_suffix = var.id_hash_suffix_from == null ? null : substr(sha1(var.id_hash_suffix_from), 0, 6)

  # Build an optional-suffix candidate without ever interpolating null:
  candidate_ids = {
    for key in keys(var.service_accounts) :
    key => join("-", compact(concat(
      length(local.primary_ids[key]) > 0 ? [local.primary_ids[key]] : [],
      local.hash_suffix == null ? [] : [local.hash_suffix]
    )))
  }

  # Filter candidates that satisfy IAM account_id rules (6–30, start letter, end alnum)
  valid_candidates = {
    for key in keys(var.service_accounts) :
    key => [
      for id in [local.candidate_ids[key], local.primary_ids[key]] :
      id if(
        length(id) >= 6
        && length(id) <= 30
        && contains(local.alpha_list, substr(id, 0, 1))
        && contains(local.alnum_chars, substr(id, length(id) - 1, 1))
        && alltrue([
          for idx in range(length(id)) : contains(local.allowed_chars, substr(id, idx, 1))
        ])
      )
    ]
  }

  # Canonical SA records
  service_accounts = {
    for key, spec in var.service_accounts : key => {
      account_id = (
        length(local.valid_candidates[key]) > 0
        ? local.valid_candidates[key][0]
        : "sa-${substr(sha1(length(local.primary_ids[key]) > 0 ? local.primary_ids[key] : key), 0, 27)}" # always 30 chars
      )

      display_name = coalesce(try(spec.display_name, null), spec.description, key)
      description  = coalesce(spec.description, key)
      disabled     = try(spec.disabled, false)
    }
  }
}