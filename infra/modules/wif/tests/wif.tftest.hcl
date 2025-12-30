# WIF module tests covering 'plan' scenarios.
# See wif_test.go for 'apply' scenarios.
run "plan_repo_only" {
  command = plan
  variables {
    project_id           = "test-project"
    pool_id              = "github-pool"
    provider_id          = "github"
    issuer_uri           = "https://token.actions.githubusercontent.com"
    allowed_repositories = ["acme/repo_a", "acme/repo_b"]
  }

  # Pool ID matches
  assert {
    condition = try(google_iam_workload_identity_pool.pool_protected[0].workload_identity_pool_id,
    google_iam_workload_identity_pool.pool_unprotected[0].workload_identity_pool_id) == "github-pool"
    error_message = "Pool ID mismatch."
  }

  # Provider mapping contains keys we rely on
  assert {
    condition = contains(keys(try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_mapping,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_mapping)), "attribute.repository")
    error_message = "attribute.repository mapping must exist."
  }
  assert {
    condition = contains(keys(try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_mapping,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_mapping)), "attribute.ref")
    error_message = "attribute.ref mapping must exist."
  }

  # Attribute condition ORs repositories; no ref term when none specified
  assert {
    condition = can(regex("attribute\\.repository == \"acme/repo_a\".*\\|\\|.*attribute\\.repository == \"acme/repo_b\"",
      try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition)))
    error_message = "attribute_condition must OR both repos."
  }
  assert {
    condition = !can(regex("attribute\\.ref",
      try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition)))
    error_message = "attribute_condition should not contain ref when none specified."
  }
}

run "plan_with_refs_and_aud" {
  command = plan
  variables {
    project_id           = "test-project"
    pool_id              = "github-pool"
    provider_id          = "github"
    issuer_uri           = "https://token.actions.githubusercontent.com"
    allowed_repositories = ["acme/repo"]
    allowed_refs         = ["refs/heads/main", "refs/heads/release/*"]
    allowed_audiences    = ["projects/123/locations/global/workloadIdentityPools/github-pool/providers/github"]
  }

  # CEL contains exact ref and prefix match
  assert {
    condition = can(regex("attribute\\.ref == \"refs/heads/main\"",
      try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition)))
    error_message = "Exact ref equality must be present."
  }
  assert {
    condition = can(regex("startsWith\\(attribute\\.ref, \"refs/heads/release/\"\\)",
      try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition)))
    error_message = "Wildcard prefix must use startsWith(attribute.ref, ...)."
  }

  # Assert that OIDC.allowed_audiences was set (one value in this test)
  assert {
    condition = length(try(google_iam_workload_identity_pool_provider.provider_protected[0].oidc[0].allowed_audiences,
      google_iam_workload_identity_pool_provider.provider_unprotected[0].oidc[0].allowed_audiences,
    [])) == 1
    error_message = "allowed_audiences should have exactly one entry in this test."
  }
}

# Owner-only selector
run "plan_owner_only" {
  command = plan
  variables {
    project_id                = "test-project"
    pool_id                   = "github-pool"
    provider_id               = "github"
    allowed_repository_owners = ["acme", "tools"]
  }
  assert {
    condition = can(regex("attribute\\.repository_owner == \"acme\".*\\|\\|.*attribute\\.repository_owner == \"tools\"",
      try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition)))
    error_message = "Owner condition must OR owners."
  }
}

# Override condition wins
run "plan_override" {
  command = plan
  variables {
    project_id                   = "test-project"
    pool_id                      = "github-pool"
    provider_id                  = "github"
    attribute_condition_override = "attribute.repository_owner == \"acme\""
  }
  assert {
    condition = try(google_iam_workload_identity_pool_provider.provider_protected[0].attribute_condition,
    google_iam_workload_identity_pool_provider.provider_unprotected[0].attribute_condition) == "attribute.repository_owner == \"acme\""
    error_message = "Override should be used verbatim."
  }
}