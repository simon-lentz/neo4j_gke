# Audit logging module tests covering 'plan' scenarios.
# See audit_logging_test.go for 'apply' scenarios.

run "plan_basic_audit_logging" {
  command = plan

  variables {
    project_id            = "test-project"
    enable_kms_audit_logs = true
    enable_gcs_audit_logs = true
    enable_log_sink       = true
  }

  assert {
    condition     = google_storage_bucket.logs.uniform_bucket_level_access == true
    error_message = "UBLA must be enabled."
  }

  assert {
    condition     = google_storage_bucket.logs.public_access_prevention == "enforced"
    error_message = "PAP must be enforced."
  }

  assert {
    condition     = length(google_storage_bucket.logs.lifecycle_rule) > 0
    error_message = "Should have lifecycle rule for log retention."
  }

  assert {
    condition     = length(google_project_iam_audit_config.kms_audit) == 1
    error_message = "Should create KMS audit config."
  }

  assert {
    condition     = length(google_project_iam_audit_config.gcs_audit) == 1
    error_message = "Should create GCS audit config."
  }

  assert {
    condition     = length(google_logging_project_sink.audit_sink) == 1
    error_message = "Should create log sink."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.sink_writer) == 1
    error_message = "Should create sink writer IAM binding."
  }
}

run "plan_custom_bucket_name" {
  command = plan

  variables {
    project_id       = "test-project"
    logs_bucket_name = "my-custom-audit-logs"
  }

  assert {
    condition     = google_storage_bucket.logs.name == "my-custom-audit-logs"
    error_message = "Should use custom bucket name."
  }
}

run "plan_disabled_audit_logs" {
  command = plan

  variables {
    project_id            = "test-project"
    enable_kms_audit_logs = false
    enable_gcs_audit_logs = false
    enable_log_sink       = false
  }

  assert {
    condition     = length(google_project_iam_audit_config.kms_audit) == 0
    error_message = "Should not create KMS audit config when disabled."
  }

  assert {
    condition     = length(google_project_iam_audit_config.gcs_audit) == 0
    error_message = "Should not create GCS audit config when disabled."
  }

  assert {
    condition     = length(google_logging_project_sink.audit_sink) == 0
    error_message = "Should not create log sink when disabled."
  }
}

run "plan_with_labels" {
  command = plan

  variables {
    project_id = "test-project"
    labels = {
      environment = "test"
      team        = "platform"
    }
  }

  assert {
    condition     = google_storage_bucket.logs.labels["environment"] == "test"
    error_message = "Should apply environment label."
  }

  assert {
    condition     = google_storage_bucket.logs.labels["team"] == "platform"
    error_message = "Should apply team label."
  }
}

run "plan_custom_retention" {
  command = plan

  variables {
    project_id         = "test-project"
    log_retention_days = 90
  }

  assert {
    condition     = length(google_storage_bucket.logs.lifecycle_rule) == 1
    error_message = "Should have exactly one lifecycle rule."
  }

  assert {
    condition     = one([for rule in google_storage_bucket.logs.lifecycle_rule : one([for cond in rule.condition : cond.age])]) == 90
    error_message = "Should use custom retention days."
  }
}
