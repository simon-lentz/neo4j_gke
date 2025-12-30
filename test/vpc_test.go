package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestVPC_CreateDescribeDestroy(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	region := "us-central1"

	tfDir := copyModuleToTemp(t, "vpc")
	suffix := strings.ToLower(random.UniqueId())
	vpcName := fmt.Sprintf("test-vpc-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":       projectID,
			"region":           region,
			"vpc_name":         vpcName,
			"enable_cloud_nat": true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify VPC exists
	networkName := terraform.Output(t, tf, "network_name")
	require.Equal(t, vpcName, networkName)

	// Verify subnet exists with secondary ranges
	subnetName := terraform.Output(t, tf, "subnet_name")
	require.NotEmpty(t, subnetName)

	// Verify secondary range names
	podsRangeName := terraform.Output(t, tf, "pods_range_name")
	require.Equal(t, "pods", podsRangeName)

	servicesRangeName := terraform.Output(t, tf, "services_range_name")
	require.Equal(t, "services", servicesRangeName)

	// Verify VPC exists via gcloud
	out := runGCLOUD(t, projectID, "compute", "networks", "describe", vpcName, "--format=value(name)")
	require.Equal(t, vpcName, strings.TrimSpace(out))

	// Verify VPC is custom mode (not auto)
	out = runGCLOUD(t, projectID, "compute", "networks", "describe", vpcName, "--format=value(autoCreateSubnetworks)")
	require.Equal(t, "false", strings.ToLower(strings.TrimSpace(out)))

	// Verify subnet exists with private Google access
	out = runGCLOUD(t, projectID, "compute", "networks", "subnets", "describe", subnetName,
		"--region", region, "--format=value(privateIpGoogleAccess)")
	requireGcloudBoolTrue(t, out)

	// Verify subnet has secondary ranges
	out = runGCLOUD(t, projectID, "compute", "networks", "subnets", "describe", subnetName,
		"--region", region, "--format=value(secondaryIpRanges[0].rangeName)")
	require.Equal(t, "pods", strings.TrimSpace(out))

	// Verify Cloud NAT exists
	natName := terraform.Output(t, tf, "nat_name")
	require.NotEmpty(t, natName)

	out = runGCLOUD(t, projectID, "compute", "routers", "nats", "describe", natName,
		"--router", fmt.Sprintf("%s-router", vpcName), "--region", region, "--format=value(name)")
	require.Equal(t, natName, strings.TrimSpace(out))
}

func TestVPC_WithoutCloudNAT(t *testing.T) {
	projectID := mustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	region := "us-central1"

	tfDir := copyModuleToTemp(t, "vpc")
	suffix := strings.ToLower(random.UniqueId())
	vpcName := fmt.Sprintf("test-vpc-nonat-%s", suffix)

	tf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    tfDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":       projectID,
			"region":           region,
			"vpc_name":         vpcName,
			"enable_cloud_nat": false,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, tf)
	terraform.InitAndApply(t, tf)

	// Verify VPC exists
	networkName := terraform.Output(t, tf, "network_name")
	require.Equal(t, vpcName, networkName)

	// Verify no NAT was created
	natName := terraform.Output(t, tf, "nat_name")
	require.Empty(t, natName)

	routerName := terraform.Output(t, tf, "router_name")
	require.Empty(t, routerName)
}
