package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestAuditLogging_CreateDescribeDestroy(t *testing.T) {
	// Sequential execution required: Tests share GCP project resources
	// and lack isolation mechanisms for safe parallel execution.

	RequireMinimumTimeout(t, DefaultTestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := CopyModuleToTemp(t, "audit_logging")
	suffix := strings.ToLower(random.UniqueId())
	bucketName := fmt.Sprintf("%s-audit-test-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":            projectID,
			"logs_bucket_name":      bucketName,
			"logs_bucket_location":  "US",
			"enable_kms_audit_logs": true,
			"enable_gcs_audit_logs": true,
			"log_retention_days":    30, // Short retention for tests
			"labels": map[string]string{
				"test": "true",
			},
		},
		NoColor: true,
	})

	DeferredTerraformCleanup(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify outputs
	outputBucketName, err := terraform.OutputE(t, tf, "logs_bucket_name")
	require.NoError(t, err, "failed to get logs_bucket_name output")
	require.Equal(t, bucketName, outputBucketName)

	bucketURL, err := terraform.OutputE(t, tf, "logs_bucket_url")
	require.NoError(t, err, "failed to get logs_bucket_url output")
	require.Equal(t, fmt.Sprintf("gs://%s", bucketName), bucketURL)

	// Verify bucket exists via gcloud
	out := runGCLOUD(t, projectID, "storage", "buckets", "describe",
		fmt.Sprintf("gs://%s", bucketName), "--format=value(name)")
	require.Equal(t, bucketName, strings.TrimSpace(out))

	// Verify UBLA is enabled
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe",
		fmt.Sprintf("gs://%s", bucketName),
		"--format=value(iamConfiguration.uniformBucketLevelAccess.enabled)")
	requireGcloudBoolTrue(t, out)

	// Verify PAP is enforced
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe",
		fmt.Sprintf("gs://%s", bucketName),
		"--format=value(iamConfiguration.publicAccessPrevention)")
	require.Equal(t, "enforced", strings.TrimSpace(strings.ToLower(out)))

	// Verify labels
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe",
		fmt.Sprintf("gs://%s", bucketName), "--format=value(labels.test)")
	require.Equal(t, "true", strings.TrimSpace(out))
}

func TestAuditLogging_DisabledAuditConfigs(t *testing.T) {
	// Sequential execution required: Tests share GCP project resources
	// and lack isolation mechanisms for safe parallel execution.

	RequireMinimumTimeout(t, DefaultTestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := CopyModuleToTemp(t, "audit_logging")
	suffix := strings.ToLower(random.UniqueId())
	bucketName := fmt.Sprintf("%s-audit-disabled-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":            projectID,
			"logs_bucket_name":      bucketName,
			"logs_bucket_location":  "US",
			"enable_kms_audit_logs": false,
			"enable_gcs_audit_logs": false,
		},
		NoColor: true,
	})

	DeferredTerraformCleanup(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify bucket still created
	outputBucketName, err := terraform.OutputE(t, tf, "logs_bucket_name")
	require.NoError(t, err, "failed to get logs_bucket_name output")
	require.Equal(t, bucketName, outputBucketName)

	// Verify audit config outputs show disabled
	kmsEnabled, err := terraform.OutputE(t, tf, "kms_audit_logs_enabled")
	require.NoError(t, err, "failed to get kms_audit_logs_enabled output")
	require.Equal(t, "false", kmsEnabled)

	gcsEnabled, err := terraform.OutputE(t, tf, "gcs_audit_logs_enabled")
	require.NoError(t, err, "failed to get gcs_audit_logs_enabled output")
	require.Equal(t, "false", gcsEnabled)
}
