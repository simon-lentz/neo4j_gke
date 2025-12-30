package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestBackupBucket_CreateDescribeDestroy(t *testing.T) {
	// Validate timeout before creating resources
	RequireMinimumTimeout(t, DefaultTestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	// First create a service account for the bucket IAM bindings
	saDir := CopyModuleToTemp(t, "service_accounts")
	suffix := strings.ToLower(random.UniqueId())

	saTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    saDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"service_accounts": map[string]any{
				fmt.Sprintf("backup-%s", suffix): map[string]any{
					"description": "Test backup SA",
				},
			},
			"prevent_destroy_service_accounts": false,
		},
		NoColor: true,
	})

	// Get SA email (known before creation)
	saEmail := fmt.Sprintf("backup-%s@%s.iam.gserviceaccount.com", suffix, projectID)

	// Create backup bucket config
	bucketDir := CopyModuleToTemp(t, "backup_bucket")
	bucketName := fmt.Sprintf("%s-backup-test-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    bucketDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":              projectID,
			"bucket_name":             bucketName,
			"location":                GetTestRegion(t),
			"backup_sa_email":         saEmail,
			"backup_retention_days":   30,
			"backup_versions_to_keep": 5,
			"force_destroy":           true,
			"labels": map[string]string{
				"test": "true",
			},
		},
		NoColor: true,
	})

	// Register cleanup for both resources BEFORE creating anything
	// Order: bucket cleanup first, then SA (LIFO)
	DeferredTerraformCleanup(t, saTf)
	DeferredTerraformCleanup(t, tf)

	terraform.InitAndApply(t, saTf)
	terraform.InitAndApply(t, tf)

	// Verify bucket was created
	outputBucketName := terraform.Output(t, tf, "bucket_name")
	require.Equal(t, bucketName, outputBucketName)

	bucketURL := terraform.Output(t, tf, "bucket_url")
	require.Equal(t, fmt.Sprintf("gs://%s", bucketName), bucketURL)

	// Verify bucket exists via gcloud
	out := runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName), "--format=value(name)")
	require.Contains(t, out, bucketName)

	// Verify UBLA is enabled
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(uniform_bucket_level_access)")
	requireGcloudBoolTrue(t, out)

	// Verify PAP is enforced
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(public_access_prevention)")
	require.Equal(t, "enforced", strings.TrimSpace(strings.ToLower(out)))

	// Verify versioning is enabled
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(versioning_enabled)")
	requireGcloudBoolTrue(t, out)

	// Verify IAM bindings
	out = runGCLOUD(t, projectID, "storage", "buckets", "get-iam-policy", fmt.Sprintf("gs://%s", bucketName), "--format=json")
	require.Contains(t, out, saEmail)
	require.Contains(t, out, "roles/storage.objectCreator")
	require.Contains(t, out, "roles/storage.objectViewer")
}

func TestBackupBucket_WithoutVersioning(t *testing.T) {
	// Validate timeout before creating resources
	RequireMinimumTimeout(t, DefaultTestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	// Create a minimal service account
	saDir := CopyModuleToTemp(t, "service_accounts")
	suffix := strings.ToLower(random.UniqueId())

	saTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    saDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"service_accounts": map[string]any{
				fmt.Sprintf("bkp-%s", suffix): map[string]any{
					"description": "Test backup SA no versioning",
				},
			},
			"prevent_destroy_service_accounts": false,
		},
		NoColor: true,
	})

	saEmail := fmt.Sprintf("bkp-%s@%s.iam.gserviceaccount.com", suffix, projectID)

	// Create bucket without versioning
	bucketDir := CopyModuleToTemp(t, "backup_bucket")
	bucketName := fmt.Sprintf("%s-novers-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    bucketDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":        projectID,
			"bucket_name":       bucketName,
			"location":          GetTestRegion(t),
			"backup_sa_email":   saEmail,
			"enable_versioning": false,
			"force_destroy":     true,
		},
		NoColor: true,
	})

	// Register cleanup for both resources BEFORE creating anything
	DeferredTerraformCleanup(t, saTf)
	DeferredTerraformCleanup(t, tf)

	terraform.InitAndApply(t, saTf)
	terraform.InitAndApply(t, tf)

	// Verify versioning is disabled
	out := runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(versioning_enabled)")
	requireGcloudBoolEquals(t, out, false)

	// Security features should still be enabled
	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(uniform_bucket_level_access)")
	requireGcloudBoolTrue(t, out)

	out = runGCLOUD(t, projectID, "storage", "buckets", "describe", fmt.Sprintf("gs://%s", bucketName),
		"--format=value(public_access_prevention)")
	require.Equal(t, "enforced", strings.TrimSpace(strings.ToLower(out)))
}
