# Basic: one SA, protected, prefix/suffix applied, display_name default = description
run "plan_basic" {
  command = plan

  variables {
    project_id = "test-project"

    sa_prefix = "tst-"
    sa_suffix = ""

    service_accounts = {
      "ci" = {
        description = "CI Service Account"
        # display_name omitted -> should default to description
      }
    }
  }

  # Protected variant should exist
  assert {
    condition     = length(google_service_account.service_account_protected) == 1
    error_message = "Expected protected SA variant."
  }

  assert {
    condition     = google_service_account.service_account_protected["ci"].account_id == "tst-ci"
    error_message = "account_id should reflect sanitized prefix+key+suffix."
  }

  assert {
    condition     = google_service_account.service_account_protected["ci"].display_name == "CI Service Account"
    error_message = "display_name should default to description."
  }

  assert {
    condition     = google_service_account.service_account_protected["ci"].disabled == false
    error_message = "disabled should default to false."
  }
}

# Toggle prevent_destroy -> unprotected variant used
run "plan_unprotected" {
  command = plan

  variables {
    project_id                       = "test-project"
    prevent_destroy_service_accounts = false

    service_accounts = {
      "ops" = { description = "Ops SA" }
    }
  }

  assert {
    condition     = length(google_service_account.service_account_unprotected) == 1
    error_message = "Expected unprotected SA variant."
  }

  # Try-get across variants to keep assert stable
  assert {
    condition = try(google_service_account.service_account_protected["ops"].account_id,
    google_service_account.service_account_unprotected["ops"].account_id) != ""
    error_message = "Expected 'ops' account_id to be set."
  }
}

# Hash suffix appended when requested, still meeting constraints
run "plan_hash_suffix" {
  command = plan

  variables {
    project_id          = "test-project"
    sa_prefix           = "ci-"
    id_hash_suffix_from = "seed-value"

    service_accounts = {
      "runner" = { description = "Runner SA" }
    }
  }

  # Expect ci-runner-<6 hex>
  assert {
    condition = can(regex("^ci-runner-[0-9a-f]{6}$",
    google_service_account.service_account_protected["runner"].account_id))
    error_message = "account_id should include 6-hex hash suffix."
  }
}

# Too-short / invalid candidate should fall back to 'sa-<27hex>'
run "plan_fallback_hashed" {
  command = plan

  variables {
    project_id = "test-project"

    service_accounts = {
      "x" = { description = "Too short key" }
    }
  }

  assert {
    condition = can(regex("^sa-[0-9a-f]{27}$",
    google_service_account.service_account_protected["x"].account_id))
    error_message = "Fallback ID should match 'sa-<27hex>'."
  }
}

# Disabled=true
run "plan_disabled_true" {
  command = plan

  variables {
    project_id = "test-project"
    service_accounts = {
      "sec" = {
        description = "Security SA"
        disabled    = true
      }
    }
  }

  assert {
    condition     = google_service_account.service_account_protected["sec"].disabled == true
    error_message = "disabled should be true when requested."
  }
}

run "plan_suffix_sanitization" {
  command = plan

  variables {
    project_id = "test-project"
    sa_suffix  = "-OPS"
    service_accounts = {
      "deploy" = {
        description  = "Deploy Service Account"
        display_name = "Deploy SA"
      }
    }
  }

  assert {
    condition     = google_service_account.service_account_protected["deploy"].account_id == "deploy-ops"
    error_message = "Suffix should be lowercased and sanitized."
  }

  assert {
    condition     = google_service_account.service_account_protected["deploy"].display_name == "Deploy SA"
    error_message = "Explicit display_name should be preserved."
  }
}