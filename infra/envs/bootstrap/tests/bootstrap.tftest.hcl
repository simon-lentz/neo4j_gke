# Bootstrap module tests covering 'plan' scenarios.
# See bootstrap_test.go for 'apply' scenarios.
run "plan_bootstrap" {
  command = plan

  variables {
    project_id               = "test-project"
    bucket_location          = "us-central1"
    kms_location             = "us-central1"
    rotation_period          = 2592000 # 30d
    retention_period_seconds = 86400
  }

  assert {
    condition     = google_storage_bucket.state_bucket.versioning[0].enabled == false
    error_message = "Versioning disabled by default (NOT recommended for production GCS backend)."
  }

  assert {
    condition     = google_storage_bucket.state_bucket.public_access_prevention == "enforced"
    error_message = "PAP must be enforced."
  }

  assert {
    condition     = google_storage_bucket.state_bucket.uniform_bucket_level_access == true
    error_message = "UBLA must be true."
  }

  assert {
    condition     = google_kms_crypto_key.state_key.rotation_period == "2592000s"
    error_message = "KMS rotation should be 30 days."
  }

  assert {
    condition     = var.kms_location == var.bucket_location
    error_message = "For this test we require KMS and bucket locations to match."
  }
}

# 1) Inference: US -> us (multi-region map)
run "plan_us_infers_kms" {
  command = plan
  variables {
    project_id      = "test-project"
    bucket_location = "US"
    # kms_location omitted on purpose
  }
  assert {
    condition     = google_kms_key_ring.state_ring.location == "us"
    error_message = "US multi-region should infer KMS location 'us'."
  }
}

# 2) Inference: NAM4 -> nam4 (predefined dual region)
run "plan_nam4_infers_kms" {
  command = plan
  variables {
    project_id      = "test-project"
    bucket_location = "NAM4"
  }
  assert {
    condition     = google_kms_key_ring.state_ring.location == "nam4"
    error_message = "NAM4 dual-region should infer KMS location 'nam4'."
  }
}

# 3) Random suffix
run "plan_random_suffix" {
  command = plan
  variables {
    project_id            = "test-project"
    bucket_location       = "us-central1"
    kms_location          = "us-central1"
    randomize_bucket_name = true
  }

  # Assert the random_id instance is created with the expected shape
  assert {
    condition     = random_id.bucket_suffix[0].byte_length == 3
    error_message = "bucket_suffix random_id must exist with byte_length=3 when randomize_bucket_name=true"
  }
}

# 4) Additional APIs de-dup and enable
run "plan_extra_apis" {
  command = plan
  variables {
    project_id                  = "test-project"
    bucket_location             = "us-central1"
    kms_location                = "us-central1"
    additional_project_services = ["cloudkms.googleapis.com", "bigquery.googleapis.com"]
  }
  assert {
    condition     = google_project_service.enabled["bigquery.googleapis.com"].service == "bigquery.googleapis.com"
    error_message = "Expected bigquery.googleapis.com to be enabled."
  }
}

# 5) Soft delete policy explicit (example: disable)
run "plan_soft_delete_off" {
  command = plan
  variables {
    project_id                    = "test-project"
    bucket_location               = "us-central1"
    kms_location                  = "us-central1"
    soft_delete_retention_seconds = 0
  }
  assert {
    condition     = length(google_storage_bucket.state_bucket.soft_delete_policy) == 1
    error_message = "soft_delete_policy should be set when provided."
  }
}

# 6) Extra IAM maps apply without churn (deterministic key)
run "plan_extra_iam" {
  command = plan
  variables {
    project_id      = "test-project"
    bucket_location = "us-central1"
    kms_location    = "us-central1"
    bucket_iam = {
      "roles/storage.objectViewer" = ["user:alice@example.com"]
    }
    kms_iam = {
      "roles/cloudkms.cryptoKeyEncrypterDecrypter" = ["user:bob@example.com"]
    }
  }

  assert {
    condition     = google_storage_bucket_iam_member.extra["roles/storage.objectViewer:user:alice@example.com"].role == "roles/storage.objectViewer"
    error_message = "Extra bucket IAM member should be planned."
  }
}