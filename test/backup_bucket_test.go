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
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	// First create a service account for the bucket IAM bindings
	saDir := copyModuleToTemp(t, "service_accounts")
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

	defer terraform.Destroy(t, saTf)
	terraform.InitAndApply(t, saTf)

	// Get SA email from output
	saEmail := fmt.Sprintf("backup-%s@%s.iam.gserviceaccount.com", suffix, projectID)

	// Create backup bucket
	bucketDir := copyModuleToTemp(t, "backup_bucket")
	bucketName := fmt.Sprintf("%s-backup-test-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    bucketDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":              projectID,
			"bucket_name":             bucketName,
			"location":                "us-central1",
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

	defer terraform.Destroy(t, tf)
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
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	// Create a minimal service account
	saDir := copyModuleToTemp(t, "service_accounts")
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

	defer terraform.Destroy(t, saTf)
	terraform.InitAndApply(t, saTf)

	saEmail := fmt.Sprintf("bkp-%s@%s.iam.gserviceaccount.com", suffix, projectID)

	// Create bucket without versioning
	bucketDir := copyModuleToTemp(t, "backup_bucket")
	bucketName := fmt.Sprintf("%s-novers-%s", projectID, suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    bucketDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":        projectID,
			"bucket_name":       bucketName,
			"location":          "us-central1",
			"backup_sa_email":   saEmail,
			"enable_versioning": false,
			"force_destroy":     true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
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
