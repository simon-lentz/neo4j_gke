# Test Suite Documentation

This directory contains integration tests for the neo4j_gke infrastructure modules using [Terratest](https://terratest.gruntwork.io/).

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEO4J_GKE_GCP_PROJECT_ID` | GCP project ID for provisioning test resources | `my-project-123` |
| `NEO4J_GKE_STATE_BUCKET_LOCATION` | GCS location for bootstrap state bucket | `us-central1` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEO4J_GKE_TEST_REGION` | Override GCP region for tests | `us-central1` |
| `NEO4J_GKE_REPO_ROOT` | Override repository root detection | Auto-detected via `.git` |

### Setup Example

```bash
export NEO4J_GKE_GCP_PROJECT_ID="my-project-123"
export NEO4J_GKE_STATE_BUCKET_LOCATION="us-central1"

# Optional overrides
export NEO4J_GKE_TEST_REGION="us-west1"
```

## Test Categories

### Quick Smoke Tests

Fast tests that validate basic module configuration without creating cloud resources:

```bash
go test -v -short ./test/...
```

### Module Integration Tests

Full integration tests that create and destroy real GCP resources:

```bash
go test -v -timeout 30m ./test/...
```

### Individual Module Tests

```bash
go test -timeout 15m -v ./test/... -run TestVPC_CreateDescribeDestroy
go test -timeout 30m -v ./test/... -run TestGKE_CreateDescribeDestroy
go test -timeout 10m -v ./test/... -run TestBootstrapSmoke
go test -timeout 10m -v ./test/... -run TestSecrets
go test -timeout 10m -v ./test/... -run TestServiceAccounts
go test -timeout 10m -v ./test/... -run TestBackupBucket
go test -timeout 10m -v ./test/... -run TestWIF
go test -timeout 10m -v ./test/... -run TestAuditLogging
```

### End-to-End Tests

Full Neo4j deployment tests (requires `e2e` build tag):

```bash
go test -tags=e2e -timeout 45m -v ./test/e2e/...
```

## Test Helpers

Key functions in `test_helpers.go`:

| Function | Description |
|----------|-------------|
| `MustEnv(t, key)` | Get required environment variable or fail test |
| `GetTestRegion(t)` | Get test region with default fallback |
| `RepoRoot(t)` | Find repository root by walking to `.git` |
| `CopyModuleToTemp(t, module)` | Copy module to temp directory for isolation |
| `CopyEnvToTemp(t, envPath)` | Copy environment config to temp directory |
| `CopyAppModuleToTemp(t, appPath)` | Copy app layer module to temp directory |
| `DeferredTerraformCleanup(t, tf)` | Register cleanup via `t.Cleanup()` |
| `DeferredTerraformCleanupMultiple(t, ...)` | Register multiple cleanups in LIFO order |
| `RequireMinimumTimeout(t, duration)` | Validate test has sufficient timeout |

## Timeout Constants

Tests use minimum timeout validation to ensure cleanup runs even if the test fails:

| Constant | Duration | Use Case |
|----------|----------|----------|
| `DefaultTestTimeout` | 10 min | Quick tests, API-only operations |
| `VPCTestTimeout` | 15 min | VPC creation/destruction |
| `GKETestTimeout` | 30 min | GKE cluster creation/destruction |
| `Neo4jTestTimeout` (e2e) | 45 min | Full stack including Neo4j deployment |

## Test Patterns

### Cleanup Registration

Always register cleanup **before** applying resources to ensure cleanup runs even if apply fails:

```go
tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{...})
testhelpers.DeferredTerraformCleanup(t, tf)  // Register cleanup first
terraform.InitAndApply(t, tf)                 // Then apply
```

### Timeout Validation

Call `RequireMinimumTimeout` at the start of tests that create cloud resources:

```go
func TestGKE_CreateDescribeDestroy(t *testing.T) {
    testhelpers.RequireMinimumTimeout(t, testhelpers.GKETestTimeout)
    // ...
}
```

### Output Error Handling

Use `terraform.OutputE()` for safe output retrieval:

```go
value, err := terraform.OutputE(t, tf, "output_name")
require.NoError(t, err, "failed to get output_name output")
```

## Parallelization

Tests run sequentially (not parallel) because:

- Tests share GCP project resources
- No isolation mechanisms for safe parallel execution
- Resource naming conflicts would occur

Each test file documents this constraint in test function comments.
