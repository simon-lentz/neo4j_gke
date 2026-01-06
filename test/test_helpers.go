package test

import (
	"flag"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/shell"
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
// If the timeout is insufficient, the test is skipped rather than failed.
// This prevents tests from timing out before cleanup can run while allowing
// quick test runs (e.g., -short mode or default timeout) to skip long tests gracefully.
// Call this at the start of any test that creates cloud resources.
func RequireMinimumTimeout(t *testing.T, minimumTimeout time.Duration) {
	t.Helper()

	// Get the test timeout from the -timeout flag
	// Default is 10 minutes if not specified
	timeout := getTestTimeout()

	if timeout > 0 && timeout < minimumTimeout {
		t.Skipf("Skipping: test timeout (%v) is less than minimum required (%v). "+
			"Run with -timeout=%v or higher. "+
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

// CopyEnvToTemp copies an environment configuration to a temp directory for testing.
// The envPath should be relative to infra/envs/ (e.g., "bootstrap", "dev").
func CopyEnvToTemp(t *testing.T, envPath string) string {
	t.Helper()

	return testStructure.CopyTerraformFolderToTemp(
		t,
		RepoRoot(t),
		filepath.Join("infra", "envs", envPath),
	)
}

// CopyAppModuleToTemp copies an app layer module to a temp directory for testing.
// The appPath should be relative to infra/apps/ (e.g., "neo4j/test").
func CopyAppModuleToTemp(t *testing.T, appPath string) string {
	t.Helper()

	return testStructure.CopyTerraformFolderToTemp(
		t,
		RepoRoot(t),
		filepath.Join("infra", "apps", appPath),
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

// --- gcloud wrappers ---

// runGCLOUD executes a gcloud command and returns stdout.
func runGCLOUD(t *testing.T, project string, args ...string) string {
	t.Helper()
	cmd := shell.Command{
		Command: "gcloud",
		Args:    append([]string{"--project", project}, args...),
	}
	out, err := shell.RunCommandAndGetStdOutE(t, cmd)
	require.NoError(t, err)
	return out
}

// runGCLOUDNoOut executes a gcloud command without capturing output.
func runGCLOUDNoOut(t *testing.T, project string, args ...string) {
	t.Helper()
	cmd := shell.Command{
		Command: "gcloud",
		Args:    append([]string{"--project", project}, args...),
	}
	err := shell.RunCommandE(t, cmd)
	require.NoError(t, err)
}

// runGCLOUDNoOutE executes a gcloud command and returns any error.
func runGCLOUDNoOutE(t *testing.T, project string, args ...string) error {
	t.Helper()
	cmd := shell.Command{
		Command: "gcloud",
		Args:    append([]string{"--project", project}, args...),
	}
	return shell.RunCommandE(t, cmd)
}

// --- gcloud assertion helpers ---

// requireGcloudBoolTrue asserts gcloud boolean output is "true".
func requireGcloudBoolTrue(t *testing.T, s string) {
	t.Helper()
	v := strings.ToLower(strings.TrimSpace(s))
	require.Equal(t, "true", v)
}

// requireGcloudBoolEquals asserts gcloud boolean output matches expected value.
// Handles gcloud's quirk of returning empty string for false.
func requireGcloudBoolEquals(t *testing.T, s string, want bool) {
	t.Helper()
	v := strings.ToLower(strings.TrimSpace(s))
	if want {
		require.Equal(t, "true", v)
	} else {
		// gcloud returns empty string for false boolean values
		require.True(t, v == "false" || v == "", "expected false or empty, got %q", v)
	}
}

// --- OpenTofu wrappers ---

// runTofu executes a tofu command with proper flag ordering.
func runTofu(t *testing.T, tf *terraform.Options, tfvarsPath string, args ...string) {
	t.Helper()
	require.GreaterOrEqual(t, len(args), 1, "tofu subcommand required")
	sub := args[0]
	rest := args[1:]

	finalArgs := []string{sub, "-input=false", "-no-color"}
	// Only pass -var-file for commands that load configuration
	if sub != "state" && tfvarsPath != "" {
		finalArgs = append(finalArgs, "-var-file="+tfvarsPath)
	}
	finalArgs = append(finalArgs, rest...)

	cmd := shell.Command{
		Command:    tf.TerraformBinary, // "tofu"
		Args:       finalArgs,
		WorkingDir: tf.TerraformDir,
		Env:        tf.EnvVars,
	}
	out, err := shell.RunCommandAndGetStdOutE(t, cmd)
	require.NoErrorf(t, err, "%s %v failed: %s", tf.TerraformBinary, finalArgs, out)
}

// runTofuE executes a tofu command and returns any error.
func runTofuE(t *testing.T, tf *terraform.Options, tfvarsPath string, args ...string) error {
	t.Helper()
	require.GreaterOrEqual(t, len(args), 1, "tofu subcommand required")
	sub := args[0]
	rest := args[1:]

	finalArgs := []string{sub, "-input=false", "-no-color"}
	if sub != "state" && tfvarsPath != "" {
		finalArgs = append(finalArgs, "-var-file="+tfvarsPath)
	}
	finalArgs = append(finalArgs, rest...)

	cmd := shell.Command{
		Command:    tf.TerraformBinary,
		Args:       finalArgs,
		WorkingDir: tf.TerraformDir,
		Env:        tf.EnvVars,
	}
	_, err := shell.RunCommandAndGetStdOutE(t, cmd)
	return err
}

// runTofuStateRmE removes a resource from tofu state and returns any error.
// 'tofu state' commands do not need variables; keep a separate helper.
func runTofuStateRmE(t *testing.T, tf *terraform.Options, addr string) error {
	t.Helper()
	cmd := shell.Command{
		Command:    tf.TerraformBinary,
		Args:       []string{"state", "rm", addr},
		WorkingDir: tf.TerraformDir,
		Env:        tf.EnvVars,
	}
	_, err := shell.RunCommandAndGetStdOutE(t, cmd)
	return err
}
