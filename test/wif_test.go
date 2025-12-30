package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestWIF_CreateDescribeDestroy(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	tfDir := copyModuleToTemp(t, "wif")
	suffix := strings.ToLower(random.UniqueId())
	poolID := fmt.Sprintf("gha-terratest-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":               projectID,
			"pool_id":                  poolID,
			"provider_id":              "github",
			"issuer_uri":               "https://token.actions.githubusercontent.com",
			"allowed_repositories":     []string{"acme/example"},
			"allowed_refs":             []string{"refs/heads/main"},
			"prevent_destroy_pool":     false,
			"prevent_destroy_provider": false,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	providerName := terraform.Output(t, tf, "provider_name")

	// gcloud describe the provider and assert issuer + condition
	out := run(t, "gcloud", "iam", "workload-identity-pools", "providers", "describe",
		providerName,
		"--format=value(oidc.issuerUri,attributeCondition)",
	)
	parts := strings.Split(strings.TrimSpace(out), "\n")
	require.GreaterOrEqual(t, len(parts), 1)
	require.Contains(t, parts[0], "https://token.actions.githubusercontent.com")
	// attribute condition should contain both repo and ref
	require.Contains(t, out, `attribute.repository == "acme/example"`)
	require.Contains(t, out, `attribute.ref == "refs/heads/main"`)
}

func TestWIF_PreconditionFailsWithoutSelectors(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	tfDir := copyModuleToTemp(t, "wif")
	suffix := strings.ToLower(random.UniqueId())
	poolID := fmt.Sprintf("gha-precond-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":  projectID,
			"pool_id":     poolID,
			"provider_id": "github",
			// NOTE: all selectors empty, no override
			"prevent_destroy_pool":     false,
			"prevent_destroy_provider": false,
		},
		NoColor: true,
	})

	_, err := terraform.InitAndPlanE(t, tf)
	require.Error(t, err)
	require.Contains(t, err.Error(), "You must specify at least one selector")
}

func run(t *testing.T, cmd string, args ...string) string {
	c := shell.Command{Command: cmd, Args: args}
	out, err := shell.RunCommandAndGetStdOutE(t, c)
	require.NoError(t, err)
	return out
}
