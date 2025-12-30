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
// This test is SLOW (15-20 minutes for creation + 5-10 minutes for cleanup).
//
// IMPORTANT: Run with sufficient timeout to allow cleanup:
//
//	go test -timeout 30m -v ./test/... -run TestGKE_CreateDescribeDestroy
//
// The test will fail fast if the timeout is insufficient, preventing orphaned resources.
func TestGKE_CreateDescribeDestroy(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GKE integration test in short mode (takes 15-20 minutes)")
	}

	// CRITICAL: Validate timeout BEFORE creating any resources.
	// GKE cluster creation takes 15-20 minutes, and cleanup takes 5-10 minutes.
	// If we don't have enough time, fail fast rather than orphan resources.
	RequireMinimumTimeout(t, GKETestTimeout)

	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	region := GetTestRegion(t)

	suffix := strings.ToLower(random.UniqueId())

	// Step 1: Create VPC first (GKE depends on it)
	vpcDir := CopyModuleToTemp(t, "vpc")
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

	// Step 2: Set up GKE terraform options (before VPC apply, for cleanup registration)
	gkeDir := CopyModuleToTemp(t, "gke")
	clusterName := fmt.Sprintf("gke-test-%s", suffix)

	// We'll set the actual network values after VPC is created
	gkeTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    gkeDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":           projectID,
			"region":               region,
			"cluster_name":         clusterName,
			"network_id":           "", // Will be set after VPC creation
			"subnet_id":            "", // Will be set after VPC creation
			"pods_range_name":      "", // Will be set after VPC creation
			"services_range_name":  "", // Will be set after VPC creation
			"deletion_protection":  false,
			"enable_container_api": true,
		},
		NoColor: true,
	})

	// Register cleanup for both resources BEFORE creating anything.
	// Order matters: GKE cleanup runs first (registered second), then VPC (registered first).
	// t.Cleanup() runs in LIFO order.
	DeferredTerraformCleanup(t, vpcTf)
	DeferredTerraformCleanup(t, gkeTf)

	// Now create the VPC
	terraform.InitAndApply(t, vpcTf)

	// Get VPC outputs and update GKE terraform options
	networkID := terraform.Output(t, vpcTf, "network_id")
	subnetID := terraform.Output(t, vpcTf, "subnet_id")
	podsRangeName := terraform.Output(t, vpcTf, "pods_range_name")
	servicesRangeName := terraform.Output(t, vpcTf, "services_range_name")

	// Update GKE options with actual VPC values
	gkeTf.Vars["network_id"] = networkID
	gkeTf.Vars["subnet_id"] = subnetID
	gkeTf.Vars["pods_range_name"] = podsRangeName
	gkeTf.Vars["services_range_name"] = servicesRangeName

	// Create the GKE cluster
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
	projectID := MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")

	gkeDir := CopyModuleToTemp(t, "gke")

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
