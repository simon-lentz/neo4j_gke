package test

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

type saInfo struct {
	Email     string `json:"email"`
	AccountID string `json:"account_id"`
	Name      string `json:"name"`
	UniqueID  string `json:"unique_id"`
}

func TestServiceAccounts_CreateDescribeDestroy(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := copyModuleToTemp(t, "service_accounts")
	suffix := strings.ToLower(random.UniqueId())
	prefix := fmt.Sprintf("it-%s-", suffix) // keeps ID <= 30 with short keys

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"sa_prefix":  prefix,
			"service_accounts": map[string]any{
				"ci": map[string]any{
					"description": "Integration CI SA",
					"disabled":    false,
				},
			},
			"prevent_destroy_service_accounts": false, // allow cleanup
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Parse the output JSON
	raw := terraform.OutputJson(t, tf, "service_accounts")
	var out map[string]saInfo
	require.NoError(t, json.Unmarshal([]byte(raw), &out))

	ci, ok := out["ci"]
	require.True(t, ok, "missing 'ci' in service_accounts output")
	require.NotEmpty(t, ci.Email)

	// gcloud describe the SA and assert disabled == false (use JSON to avoid empty-string edge case)
	outJSON := runGCLOUD(t, projectID, "iam", "service-accounts", "describe",
		ci.Email, "--format=json")
	var resp struct {
		Disabled bool `json:"disabled"`
	}
	require.NoError(t, json.Unmarshal([]byte(outJSON), &resp))
	require.False(t, resp.Disabled, "service account should not be disabled")
}
