# Backup bucket module tests covering 'plan' scenarios.
# See backup_bucket_test.go for 'apply' scenarios.

run "plan_backup_bucket" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-project-backups"
    location        = "us-central1"
    backup_sa_email = "backup@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = google_storage_bucket.backups.uniform_bucket_level_access == true
    error_message = "UBLA must be enabled."
  }

  assert {
    condition     = google_storage_bucket.backups.public_access_prevention == "enforced"
    error_message = "PAP must be enforced."
  }

  assert {
    condition     = google_storage_bucket.backups.versioning[0].enabled == true
    error_message = "Versioning should be enabled by default."
  }
}

run "plan_bucket_location" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-backups-regional"
    location        = "us-east1"
    backup_sa_email = "backup@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = google_storage_bucket.backups.location == "US-EAST1"
    error_message = "Bucket location should match input (uppercase)."
  }
}

run "plan_storage_class" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-backups-nearline"
    location        = "us-central1"
    backup_sa_email = "backup@test-project.iam.gserviceaccount.com"
    storage_class   = "NEARLINE"
  }

  assert {
    condition     = google_storage_bucket.backups.storage_class == "NEARLINE"
    error_message = "Storage class should be NEARLINE."
  }
}

run "plan_iam_bindings" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-backups-iam"
    location        = "us-central1"
    backup_sa_email = "neo4j-backup@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = google_storage_bucket_iam_member.backup_creator.role == "roles/storage.objectCreator"
    error_message = "Should grant objectCreator role."
  }

  assert {
    condition     = google_storage_bucket_iam_member.backup_viewer.role == "roles/storage.objectViewer"
    error_message = "Should grant objectViewer role."
  }

  assert {
    condition     = google_storage_bucket_iam_member.backup_creator.member == "serviceAccount:neo4j-backup@test-project.iam.gserviceaccount.com"
    error_message = "IAM member should be the backup SA."
  }
}

run "plan_lifecycle_rules" {
  command = plan

  variables {
    project_id              = "test-project"
    bucket_name             = "test-backups-lifecycle"
    location                = "us-central1"
    backup_sa_email         = "backup@test-project.iam.gserviceaccount.com"
    backup_retention_days   = 60
    backup_versions_to_keep = 10
  }

  assert {
    condition     = length(google_storage_bucket.backups.lifecycle_rule) == 2
    error_message = "Should have 2 lifecycle rules (retention + versions)."
  }
}

run "plan_no_retention" {
  command = plan

  variables {
    project_id            = "test-project"
    bucket_name           = "test-backups-no-retention"
    location              = "us-central1"
    backup_sa_email       = "backup@test-project.iam.gserviceaccount.com"
    backup_retention_days = 0
  }

  assert {
    condition     = length([for r in google_storage_bucket.backups.lifecycle_rule : r if try(r.condition[0].age, null) != null]) == 0
    error_message = "Should have no age-based lifecycle rule when retention is 0."
  }
}

run "plan_force_destroy" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-backups-dev"
    location        = "us-central1"
    backup_sa_email = "backup@test-project.iam.gserviceaccount.com"
    force_destroy   = true
  }

  assert {
    condition     = google_storage_bucket.backups.force_destroy == true
    error_message = "force_destroy should be enabled for dev."
  }
}

run "plan_versioning_disabled" {
  command = plan

  variables {
    project_id        = "test-project"
    bucket_name       = "test-backups-no-versioning"
    location          = "us-central1"
    backup_sa_email   = "backup@test-project.iam.gserviceaccount.com"
    enable_versioning = false
  }

  assert {
    condition     = google_storage_bucket.backups.versioning[0].enabled == false
    error_message = "Versioning should be disabled when requested."
  }
}

run "plan_labels" {
  command = plan

  variables {
    project_id      = "test-project"
    bucket_name     = "test-backups-labeled"
    location        = "us-central1"
    backup_sa_email = "backup@test-project.iam.gserviceaccount.com"
    labels = {
      environment = "dev"
      purpose     = "neo4j-backup"
    }
  }

  assert {
    condition     = google_storage_bucket.backups.labels["environment"] == "dev"
    error_message = "Labels should be applied."
  }

  assert {
    condition     = google_storage_bucket.backups.labels["purpose"] == "neo4j-backup"
    error_message = "All labels should be applied."
  }
}
