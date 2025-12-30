package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TestGKE_CreateDescribeDestroy creates a full GKE Autopilot cluster.
// This test is SLOW (10-15 minutes) and should be skipped in short mode.
func TestGKE_CreateDescribeDestroy(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GKE integration test in short mode (takes 10-15 minutes)")
	}

	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	region := "us-central1"

	suffix := strings.ToLower(random.UniqueId())

	// Step 1: Create VPC first (GKE depends on it)
	vpcDir := copyModuleToTemp(t, "vpc")
	vpcName := fmt.Sprintf("gke-test-vpc-%s", suffix)

	vpcTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    vpcDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":       projectID,
			"region":           region,
			"vpc_name":         vpcName,
			"enable_cloud_nat": true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, vpcTf)
	terraform.InitAndApply(t, vpcTf)

	// Get VPC outputs
	networkID := terraform.Output(t, vpcTf, "network_id")
	subnetID := terraform.Output(t, vpcTf, "subnet_id")
	podsRangeName := terraform.Output(t, vpcTf, "pods_range_name")
	servicesRangeName := terraform.Output(t, vpcTf, "services_range_name")

	// Step 2: Create GKE cluster
	gkeDir := copyModuleToTemp(t, "gke")
	clusterName := fmt.Sprintf("gke-test-%s", suffix)

	gkeTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    gkeDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":           projectID,
			"region":               region,
			"cluster_name":         clusterName,
			"network_id":           networkID,
			"subnet_id":            subnetID,
			"pods_range_name":      podsRangeName,
			"services_range_name":  servicesRangeName,
			"deletion_protection":  false,
			"enable_container_api": true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, gkeTf)
	terraform.InitAndApply(t, gkeTf)

	// Verify cluster was created
	outputClusterName := terraform.Output(t, gkeTf, "cluster_name")
	require.Equal(t, clusterName, outputClusterName)

	// Verify Workload Identity pool
	wiPool := terraform.Output(t, gkeTf, "workload_identity_pool")
	require.Equal(t, fmt.Sprintf("%s.svc.id.goog", projectID), wiPool)

	// Verify cluster exists via gcloud
	out := runGCLOUD(t, projectID, "container", "clusters", "describe", clusterName,
		"--region", region, "--format=value(name)")
	require.Equal(t, clusterName, strings.TrimSpace(out))

	// Verify it's an Autopilot cluster
	out = runGCLOUD(t, projectID, "container", "clusters", "describe", clusterName,
		"--region", region, "--format=value(autopilot.enabled)")
	requireGcloudBoolTrue(t, out)

	// Verify private nodes are enabled
	out = runGCLOUD(t, projectID, "container", "clusters", "describe", clusterName,
		"--region", region, "--format=value(privateClusterConfig.enablePrivateNodes)")
	requireGcloudBoolTrue(t, out)

	// Verify master endpoint is public (private endpoint disabled by default)
	out = runGCLOUD(t, projectID, "container", "clusters", "describe", clusterName,
		"--region", region, "--format=value(privateClusterConfig.enablePrivateEndpoint)")
	requireGcloudBoolEquals(t, out, false)

	// Verify release channel
	out = runGCLOUD(t, projectID, "container", "clusters", "describe", clusterName,
		"--region", region, "--format=value(releaseChannel.channel)")
	require.Equal(t, "REGULAR", strings.TrimSpace(out))
}

// TestGKE_PlanOnly validates the GKE module configuration without creating resources.
// Use this for quick validation during development.
func TestGKE_PlanOnly(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	gkeDir := copyModuleToTemp(t, "gke")

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    gkeDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":           projectID,
			"region":               "us-central1",
			"cluster_name":         "plan-test-cluster",
			"network_id":           "projects/test/global/networks/test-vpc",
			"subnet_id":            "projects/test/regions/us-central1/subnetworks/test-subnet",
			"pods_range_name":      "pods",
			"services_range_name":  "services",
			"deletion_protection":  false,
			"enable_container_api": false,
		},
		NoColor: true,
	})

	// Only run init and plan (no apply)
	terraform.Init(t, tf)
	planOutput := terraform.Plan(t, tf)

	// Verify plan contains expected resources
	require.Contains(t, planOutput, "google_container_cluster.autopilot")
}
