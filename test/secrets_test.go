package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestSecrets_CreateDescribeDestroy(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := copyModuleToTemp(t, "secrets")
	suffix := strings.ToLower(random.UniqueId())
	secretName := fmt.Sprintf("test-secret-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"secrets": map[string]any{
				secretName: map[string]any{
					"description": "Integration test secret",
					"labels": map[string]string{
						"test": "true",
					},
				},
			},
			"enable_secret_manager_api": true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify secret was created
	secretIDs := terraform.OutputMap(t, tf, "secret_ids")
	require.Contains(t, secretIDs, secretName)
	require.Equal(t, secretName, secretIDs[secretName])

	// Verify secret exists via gcloud
	out := runGCLOUD(t, projectID, "secrets", "describe", secretName, "--format=value(name)")
	require.Contains(t, out, secretName)

	// Verify labels
	out = runGCLOUD(t, projectID, "secrets", "describe", secretName, "--format=value(labels.test)")
	require.Equal(t, "true", strings.TrimSpace(out))
}

func TestSecrets_WithAccessors(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	// First create a service account to grant access to
	saDir := copyModuleToTemp(t, "service_accounts")
	saSuffix := strings.ToLower(random.UniqueId())
	saName := fmt.Sprintf("test-sa-%s", saSuffix)

	saTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    saDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"service_accounts": map[string]any{
				saName: map[string]any{
					"description": "Test SA for secrets accessor",
				},
			},
			"prevent_destroy_service_accounts": false,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, saTf)
	terraform.InitAndApply(t, saTf)

	// Get SA email
	saOutput := terraform.OutputJson(t, saTf, "service_accounts")
	// Parse just to get the email
	saEmail := fmt.Sprintf("%s@%s.iam.gserviceaccount.com", saName, projectID)

	// Now create secret with accessor
	secretDir := copyModuleToTemp(t, "secrets")
	suffix := strings.ToLower(random.UniqueId())
	secretName := fmt.Sprintf("test-secret-acl-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    secretDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"secrets": map[string]any{
				secretName: map[string]any{
					"description": "Secret with accessor",
				},
			},
			"accessors": map[string][]string{
				secretName: {fmt.Sprintf("serviceAccount:%s", saEmail)},
			},
			"enable_secret_manager_api": false, // Already enabled
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify secret was created
	secretIDs := terraform.OutputMap(t, tf, "secret_ids")
	require.Contains(t, secretIDs, secretName)

	// Verify IAM binding via gcloud
	out := runGCLOUD(t, projectID, "secrets", "get-iam-policy", secretName, "--format=json")
	require.Contains(t, out, saEmail)
	require.Contains(t, out, "roles/secretmanager.secretAccessor")

	// Keep reference to saOutput to avoid unused variable error
	_ = saOutput
}

func TestSecrets_MultipleSecrets(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := copyModuleToTemp(t, "secrets")
	suffix := strings.ToLower(random.UniqueId())

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"secrets": map[string]any{
				fmt.Sprintf("secret-one-%s", suffix): map[string]any{
					"description": "First secret",
				},
				fmt.Sprintf("secret-two-%s", suffix): map[string]any{
					"description": "Second secret",
					"labels": map[string]string{
						"priority": "high",
					},
				},
			},
			"enable_secret_manager_api": false,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify both secrets were created
	secretIDs := terraform.OutputMap(t, tf, "secret_ids")
	require.Len(t, secretIDs, 2)
	require.Contains(t, secretIDs, fmt.Sprintf("secret-one-%s", suffix))
	require.Contains(t, secretIDs, fmt.Sprintf("secret-two-%s", suffix))
}
