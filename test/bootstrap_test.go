package test

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestBootstrapSmoke(t *testing.T) {
	// Do not parallelize: we adopt a fixed KMS ring/key per project.
	// t.Parallel()

	// Validate timeout before creating resources
	RequireMinimumTimeout(t, DefaultTestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	location := MustEnv(t, "NEO4J_GKE_STATE_BUCKET_LOCATION") // e.g., us-central1

	// Work in a temp copy so state and .terraform are isolated per run.
	tfDir := CopyModuleToTemp(t, "bootstrap")

	unique := strings.ToLower(random.UniqueId())

	// Stable KMS names (match module defaults) so we can adopt/import if they exist.
	ringName := fmt.Sprintf("%s-tfstate-ring", projectID)
	keyName := "tfstate-key"

	// Ephemeral bucket
	bucketName := fmt.Sprintf("%s-state-%s", projectID, unique)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu", // ensure OpenTofu binary
		Vars: map[string]any{
			"project_id":      projectID,
			"bucket_location": location,
			"bucket_name":     bucketName,
			// allow bucket versioning to default to false to avoid ephemeral test
			// objects from being persisted after test completion
			"bucket_versioning": false,
			"kms_location":      location,
			"kms_key_ring_name": ringName,
			"kms_key_name":      keyName,
			"rotation_period":   2592000, // 30d
			// allow retention period to default to null to avoid ephemeral test
			// objects from being persisted after test completion
			"force_destroy": true,
			"labels":        map[string]string{"component": "bootstrap", "test": "true"},
		},
		NoColor: true,
		EnvVars: map[string]string{
			"GOOGLE_PROJECT": projectID,
		},
	})

	// Custom cleanup: destroy only ephemeral resources, then untrack KMS in state.
	// Using t.Cleanup() for better cleanup guarantees.
	t.Cleanup(func() {
		cleanupEphemeral(t, tf, projectID, bucketName)
	})

	terraform.Init(t, tf)

	// Ensure a tfvars JSON is present for non-interactive tofu commands (import/destroy).
	tfvarsPath := ensureTfVarsJSON(t, tf)

	// Adopt KMS resources (rings/keys are not deletable in GCP).
	ringID := fmt.Sprintf("projects/%s/locations/%s/keyRings/%s", projectID, location, ringName)
	if kmsKeyRingExists(t, projectID, location, ringName) {
		tofuImport(t, tf, tfvarsPath, "google_kms_key_ring.state_ring", ringID)
	}

	keyID := fmt.Sprintf("%s/cryptoKeys/%s", ringID, keyName)
	if kmsCryptoKeyExists(t, projectID, location, ringName, keyName) {
		tofuImport(t, tf, tfvarsPath, "google_kms_crypto_key.state_key", keyID)
	}

	// Apply (terratest wrapper will pass Vars for us)
	terraform.Apply(t, tf)

	// We need the bucket URL in gs://bucket format for the describe command
	bucketURL := fmt.Sprintf("gs://%s", bucketName)

	// --- Assertions ---

	// 1) Bucket exists
	out := runGCLOUD(t, projectID, "storage", "buckets", "describe", bucketURL)
	require.Contains(t, out, bucketName)

	// 2) UBLA & PAP (use snake_case fields for gcloud storage)
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", bucketURL, "--format=value(uniform_bucket_level_access)")
	requireGcloudBoolTrue(t, out)

	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", bucketURL, "--format=value(public_access_prevention)")
	require.Equal(t, "enforced", strings.TrimSpace(strings.ToLower(out)))

	// 3) Versioning equals our configured value (we passed bucket_versioning=false)
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", bucketURL, "--format=value(versioning_enabled)")
	requireGcloudBoolEquals(t, out, false)

	// 4) Default KMS key set and usable (we only need the field presence)
	stateObj, outputErr := terraform.OutputE(t, tf, "state")
	require.NoError(t, outputErr, "failed to get state output")
	require.Contains(t, stateObj, "kms_key_name")

	// 5) Simple write/read roundtrip
	obj := fmt.Sprintf("it/%d.txt", time.Now().UnixNano())

	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "payload.txt")
	err := os.WriteFile(tmpFile, []byte("ok"), 0600)
	require.NoError(t, err)

	runGCLOUDNoOut(t, projectID, "storage", "cp", tmpFile, fmt.Sprintf("gs://%s/%s", bucketName, obj), "--quiet")

	read := runGCLOUD(t, projectID, "storage", "cat", fmt.Sprintf("gs://%s/%s", bucketName, obj))
	require.Equal(t, "ok", strings.TrimSpace(read))

	// 6) Anonymous read should fail (PAP enforced)
	cmd := shell.Command{
		Command: "curl",
		Args:    []string{"-sSf", fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, obj)},
	}
	_, err = shell.RunCommandAndGetStdOutE(t, cmd)
	require.Error(t, err, "anonymous read unexpectedly succeeded; PAP should be enforced")

	// 7a) Bucket default key is set to our key
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", bucketURL, "--format=default(default_kms_key)")
	require.Equal(t, fmt.Sprintf("default_kms_key: %s", keyID), strings.TrimSpace(out))

	// 7b) The uploaded object was encrypted with our CMEK
	out = runGCLOUD(t, projectID, "storage", "objects", "describe", fmt.Sprintf("gs://%s/%s", bucketName, obj), "--format=default(kms_key)")
	require.Contains(t, out, fmt.Sprintf("kms_key: %s", keyID), strings.TrimSpace(out))

	// Proactively delete the test object to keep the bucket empty.
	runGCLOUDNoOut(t, projectID, "storage", "rm", "--quiet", fmt.Sprintf("gs://%s/%s", bucketName, obj))
}

// --- write a tfvars JSON alongside the temp module so tofu import/destroy have vars ---
func ensureTfVarsJSON(t *testing.T, tf *terraform.Options) string {
	path := filepath.Join(tf.TerraformDir, "terratest.auto.tfvars.json")
	data, err := json.MarshalIndent(tf.Vars, "", "  ")
	require.NoError(t, err)
	err = os.WriteFile(path, data, 0600)
	require.NoError(t, err)
	return path
}

// --- cleanup: only ephemeral resources, then drop imported KMS from state ---
func cleanupEphemeral(t *testing.T, tf *terraform.Options, projectID, bucketName string) {
	tfvarsPath := filepath.Join(tf.TerraformDir, "terratest.auto.tfvars.json")

	// If we never got to Init/Apply, state may not exist; target destroy is harmless but
	// we still pass var-file to avoid prompts.
	if err := runTofuE(t, tf, tfvarsPath, "destroy", "-auto-approve",
		"-target=google_storage_bucket_iam_member.extra",
		"-target=google_kms_crypto_key_iam_member.extra",
		"-target=google_storage_bucket.state_bucket",
	); err != nil {
		t.Logf("cleanup: tofu destroy returned error (ignored): %v", err)
	}

	// Remove KMS from state so future runs don't try to delete/import incorrectly.
	// (Skip var-file for 'state' sub-commands; they don't need config vars.)
	if err := runTofuStateRmE(t, tf, "google_kms_crypto_key.state_key"); err != nil {
		t.Logf("cleanup: tofu state rm (crypto key) returned error (ignored): %v", err)
	}
	if err := runTofuStateRmE(t, tf, "google_kms_key_ring.state_ring"); err != nil {
		t.Logf("cleanup: tofu state rm (key ring) returned error (ignored): %v", err)
	}

	// Final safeguard: attempt to delete the bucket directly, ignoring errors if it
	// already vanished or was never created.
	if bucketName != "" {
		if err := runGCLOUDNoOutE(t, projectID, "storage", "buckets", "delete", fmt.Sprintf("gs://%s", bucketName), "--quiet"); err != nil {
			t.Logf("cleanup: best-effort gcloud bucket delete failed for %s: %v", bucketName, err)
		}
	}
}

// --- tofu import wrapper (no terratest Import available in your version) ---
func tofuImport(t *testing.T, tf *terraform.Options, tfvarsPath, addr, id string) {
	runTofu(t, tf, tfvarsPath, "import", addr, id)
}

// --- existence checks: rely on exit code; no --format to avoid zsh quirks ---
func kmsKeyRingExists(t *testing.T, project, location, ring string) bool {
	cmd := shell.Command{
		Command: "gcloud",
		Args:    []string{"--project", project, "kms", "keyrings", "describe", ring, "--location", location},
	}
	_, err := shell.RunCommandAndGetStdOutE(t, cmd)
	return err == nil
}

func kmsCryptoKeyExists(t *testing.T, project, location, ring, key string) bool {
	cmd := shell.Command{
		Command: "gcloud",
		Args:    []string{"--project", project, "kms", "keys", "describe", key, "--keyring", ring, "--location", location},
	}
	_, err := shell.RunCommandAndGetStdOutE(t, cmd)
	return err == nil
}
