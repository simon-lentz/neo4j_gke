package test

import (
	"flag"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

// Default test timeouts for different resource types.
// These are minimum recommended timeouts to ensure cleanup runs.
const (
	// DefaultTestTimeout is the minimum timeout for quick tests
	DefaultTestTimeout = 10 * time.Minute
	// GKETestTimeout is the minimum timeout for tests that create GKE clusters
	GKETestTimeout = 30 * time.Minute
	// VPCTestTimeout is the minimum timeout for tests that create VPCs
	VPCTestTimeout = 15 * time.Minute
)

// RequireMinimumTimeout validates that the test has sufficient timeout configured.
// This prevents tests from timing out before cleanup can run.
// Call this at the start of any test that creates cloud resources.
func RequireMinimumTimeout(t *testing.T, minimumTimeout time.Duration) {
	t.Helper()

	// Get the test timeout from the -timeout flag
	// Default is 10 minutes if not specified
	timeout := getTestTimeout()

	if timeout > 0 && timeout < minimumTimeout {
		t.Fatalf("Test timeout (%v) is less than minimum required (%v). "+
			"Run with -timeout=%v or higher to ensure cleanup runs. "+
			"Example: go test -timeout=%v ./test/...",
			timeout, minimumTimeout, minimumTimeout, minimumTimeout)
	}
}

// getTestTimeout returns the test timeout from the -timeout flag.
// Returns 0 if no timeout was specified (infinite).
func getTestTimeout() time.Duration {
	// The -timeout flag is parsed by the testing package
	f := flag.Lookup("test.timeout")
	if f == nil {
		return 10 * time.Minute // Go's default
	}

	// Parse the duration value
	if d, err := time.ParseDuration(f.Value.String()); err == nil {
		return d
	}

	return 10 * time.Minute // Go's default
}

// DeferredTerraformCleanup registers terraform destroy as a cleanup function.
// This uses t.Cleanup() which has better guarantees than defer:
// - Runs even if the test calls t.FailNow() or t.Fatal()
// - Runs cleanup functions in LIFO order
// - Still subject to test timeout (see RequireMinimumTimeout)
//
// IMPORTANT: For long-running tests, always call RequireMinimumTimeout() first
// to ensure the test has enough time for both execution AND cleanup.
//
// Usage:
//
//	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{...})
//	DeferredTerraformCleanup(t, tf)
//	terraform.InitAndApply(t, tf)
func DeferredTerraformCleanup(t *testing.T, options *terraform.Options) {
	t.Helper()

	t.Cleanup(func() {
		// Use a recovery to handle any panics during cleanup
		defer func() {
			if r := recover(); r != nil {
				t.Logf("CLEANUP PANIC (resources may be orphaned): %v", r)
				t.Logf("TerraformDir: %s", options.TerraformDir)
				t.Logf("Manual cleanup may be required")
			}
		}()

		t.Logf("Running terraform destroy for cleanup...")
		if _, err := terraform.DestroyE(t, options); err != nil {
			t.Logf("CLEANUP ERROR (resources may be orphaned): %v", err)
			t.Logf("TerraformDir: %s", options.TerraformDir)
			t.Logf("Manual cleanup may be required")
		}
	})
}

// DeferredTerraformCleanupMultiple registers multiple terraform options for cleanup.
// Cleanup runs in reverse order (LIFO) - last registered is cleaned up first.
// This is useful for tests that create dependent resources (e.g., GKE depends on VPC).
//
// Usage:
//
//	vpcTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{...})
//	gkeTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{...})
//	DeferredTerraformCleanupMultiple(t, vpcTf, gkeTf)  // gkeTf destroyed first, then vpcTf
//	terraform.InitAndApply(t, vpcTf)
//	terraform.InitAndApply(t, gkeTf)
func DeferredTerraformCleanupMultiple(t *testing.T, options ...*terraform.Options) {
	t.Helper()

	// Register in order - t.Cleanup runs in LIFO order automatically
	for _, opt := range options {
		DeferredTerraformCleanup(t, opt)
	}
}

// MustEnv fetches an environment variable or fails the test.
func MustEnv(t *testing.T, k string) string {
	t.Helper()
	v := os.Getenv(k)
	if v == "" {
		t.Fatalf("required environment variable %s is not set", k)
	}
	return v
}

// RepoRoot locates the repository root by walking parent directories until a
// .git directory is discovered. It honours the NEO4J_GKE_REPO_ROOT override so
// callers can short-circuit discovery if desired.
func RepoRoot(t *testing.T) string {
	t.Helper()

	if override := strings.TrimSpace(os.Getenv("NEO4J_GKE_REPO_ROOT")); override != "" {
		return override
	}

	dir, err := os.Getwd()
	require.NoError(t, err)

	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}

		parent := filepath.Dir(dir)
		require.NotEqualf(t, parent, dir, "could not locate repository root from %s; set NEO4J_GKE_REPO_ROOT", dir)
		dir = parent
	}
}

// CopyModuleToTemp mirrors the previous behaviour of CopyTerraformFolderToTemp
// but with paths relative to the repository root now that the tests live under
// infrastructure/test/.
func CopyModuleToTemp(t *testing.T, moduleRelativePath string) string {
	t.Helper()

	return testStructure.CopyTerraformFolderToTemp(
		t,
		RepoRoot(t),
		filepath.Join("infra", "modules", moduleRelativePath),
	)
}

// GetTestRegion returns the GCP region for tests, defaulting to us-central1.
// Override via NEO4J_GKE_TEST_REGION environment variable.
func GetTestRegion(t *testing.T) string {
	t.Helper()
	region := os.Getenv("NEO4J_GKE_TEST_REGION")
	if region == "" {
		region = "us-central1"
	}
	return region
}
