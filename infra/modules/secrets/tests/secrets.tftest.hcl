# Secrets module tests covering 'plan' scenarios.
# See secrets_test.go for 'apply' scenarios.

run "plan_basic_secret" {
  command = plan

  variables {
    project_id = "test-project"
    secrets = {
      "test-secret" = {
        description = "Test secret for plan validation"
      }
    }
    enable_secret_manager_api = false
  }

  assert {
    condition     = length(google_secret_manager_secret.secrets) == 1
    error_message = "Should create exactly one secret."
  }

  assert {
    condition     = google_secret_manager_secret.secrets["test-secret"].secret_id == "test-secret"
    error_message = "Secret ID should match the key."
  }
}

run "plan_multiple_secrets" {
  command = plan

  variables {
    project_id = "test-project"
    secrets = {
      "secret-one" = {
        description = "First secret"
      }
      "secret-two" = {
        description = "Second secret"
        labels      = { team = "platform" }
      }
    }
    enable_secret_manager_api = false
  }

  assert {
    condition     = length(google_secret_manager_secret.secrets) == 2
    error_message = "Should create two secrets."
  }

  assert {
    condition     = google_secret_manager_secret.secrets["secret-two"].labels["team"] == "platform"
    error_message = "Secret should have labels applied."
  }
}

run "plan_with_accessors" {
  command = plan

  variables {
    project_id = "test-project"
    secrets = {
      "my-secret" = {
        description = "Secret with accessors"
      }
    }
    accessors = {
      "my-secret" = ["serviceAccount:test@test-project.iam.gserviceaccount.com"]
    }
    enable_secret_manager_api = false
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessor) == 1
    error_message = "Should create one IAM binding."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.accessor["my-secret:serviceAccount:test@test-project.iam.gserviceaccount.com"].role == "roles/secretmanager.secretAccessor"
    error_message = "IAM binding should have secretAccessor role."
  }
}

run "plan_enable_api" {
  command = plan

  variables {
    project_id = "test-project"
    secrets = {
      "api-secret" = {
        description = "Secret requiring API enablement"
      }
    }
    enable_secret_manager_api = true
  }

  assert {
    condition     = length(google_project_service.secretmanager) == 1
    error_message = "Should enable Secret Manager API."
  }

  assert {
    condition     = google_project_service.secretmanager[0].service == "secretmanager.googleapis.com"
    error_message = "Should enable secretmanager.googleapis.com."
  }
}

run "plan_automatic_replication" {
  command = plan

  variables {
    project_id = "test-project"
    secrets = {
      "auto-replicated" = {
        description = "Auto-replicated secret"
        replication = "automatic"
      }
    }
    enable_secret_manager_api = false
  }

  assert {
    condition     = length(google_secret_manager_secret.secrets["auto-replicated"].replication) == 1
    error_message = "Should have replication configured."
  }
}

run "plan_no_secrets" {
  command = plan

  variables {
    project_id                = "test-project"
    secrets                   = {}
    enable_secret_manager_api = false
  }

  assert {
    condition     = length(google_secret_manager_secret.secrets) == 0
    error_message = "Should create no secrets when map is empty."
  }
}
