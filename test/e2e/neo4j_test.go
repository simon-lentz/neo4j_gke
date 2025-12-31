//go:build e2e

// Package e2e contains end-to-end integration tests that deploy full infrastructure.
// These tests are excluded from normal test runs and must be explicitly enabled.
//
// Run e2e tests with:
//
//	go test -tags=e2e -timeout 45m -v ./test/e2e/...
//
// Required environment variables:
//   - NEO4J_GKE_GCP_PROJECT_ID: GCP project ID
package e2e

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"

	testhelpers "github.com/simon-lentz/neo4j_gke/test"
)

// Neo4jTestTimeout is the minimum timeout for tests that deploy Neo4j.
// This includes: VPC (~5 min) + GKE (~15 min) + Neo4j (~10 min) + cleanup (~10 min)
const Neo4jTestTimeout = 45 * time.Minute

// TestNeo4j_FullDeployment performs a full integration test of the Neo4j deployment.
// This test is SLOW (30-40 minutes) and is only run when the e2e build tag is enabled.
// It deploys VPC + GKE (platform layer) + Neo4j and verifies Neo4j is running.
//
// IMPORTANT: Run with sufficient timeout:
//
//	go test -tags=e2e -timeout 45m -v ./test/e2e/... -run TestNeo4j_FullDeployment
//
// Required environment variables:
//   - NEO4J_GKE_GCP_PROJECT_ID: GCP project ID
func TestNeo4j_FullDeployment(t *testing.T) {
	// Sequential execution required: Tests share GCP project resources
	// and lack isolation mechanisms for safe parallel execution.

	// CRITICAL: Validate timeout BEFORE creating any resources.
	testhelpers.RequireMinimumTimeout(t, Neo4jTestTimeout)

	projectID := testhelpers.MustEnv(t, "NEO4J_GKE_GCP_PROJECT_ID")
	region := testhelpers.GetTestRegion(t)
	suffix := strings.ToLower(random.UniqueId())

	t.Logf("Starting Neo4j full deployment test with suffix: %s", suffix)

	// -------------------------------------------------------------------------
	// Step 1: Create VPC
	// -------------------------------------------------------------------------
	t.Log("Step 1: Creating VPC...")
	vpcDir := testhelpers.CopyModuleToTemp(t, "vpc")
	vpcName := fmt.Sprintf("neo4j-test-vpc-%s", suffix)

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

	// -------------------------------------------------------------------------
	// Step 2: Set up GKE options
	// -------------------------------------------------------------------------
	gkeDir := testhelpers.CopyModuleToTemp(t, "gke")
	clusterName := fmt.Sprintf("neo4j-test-%s", suffix)

	gkeTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    gkeDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":           projectID,
			"region":               region,
			"cluster_name":         clusterName,
			"network_id":           "", // Set after VPC creation
			"subnet_id":            "", // Set after VPC creation
			"pods_range_name":      "", // Set after VPC creation
			"services_range_name":  "", // Set after VPC creation
			"deletion_protection":  false,
			"enable_container_api": true,
		},
		NoColor: true,
	})

	// -------------------------------------------------------------------------
	// Step 3: Set up service account options
	// -------------------------------------------------------------------------
	saDir := testhelpers.CopyModuleToTemp(t, "service_accounts")
	backupSAName := fmt.Sprintf("neo4j-bk-%s", suffix)

	saTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    saDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id": projectID,
			"service_accounts": map[string]any{
				backupSAName: map[string]any{
					"description": "Neo4j backup SA for integration test",
				},
			},
			"prevent_destroy_service_accounts": false,
		},
		NoColor: true,
	})

	// -------------------------------------------------------------------------
	// Step 4: Set up backup bucket options
	// -------------------------------------------------------------------------
	bucketDir := testhelpers.CopyModuleToTemp(t, "backup_bucket")
	backupBucketName := fmt.Sprintf("%s-neo4j-bkp-%s", projectID, suffix)

	bucketTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    bucketDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":        projectID,
			"bucket_name":       backupBucketName,
			"location":          region,
			"backup_sa_email":   fmt.Sprintf("%s@%s.iam.gserviceaccount.com", backupSAName, projectID),
			"enable_versioning": false,
			"force_destroy":     true,
		},
		NoColor: true,
	})

	// Register cleanup in reverse dependency order (LIFO).
	// Order: bucket -> SA -> GKE -> VPC
	testhelpers.DeferredTerraformCleanup(t, vpcTf)
	testhelpers.DeferredTerraformCleanup(t, gkeTf)
	testhelpers.DeferredTerraformCleanup(t, saTf)
	testhelpers.DeferredTerraformCleanup(t, bucketTf)

	// -------------------------------------------------------------------------
	// Apply VPC
	// -------------------------------------------------------------------------
	terraform.InitAndApply(t, vpcTf)

	networkID, err := terraform.OutputE(t, vpcTf, "network_id")
	require.NoError(t, err, "failed to get network_id output")
	subnetID, err := terraform.OutputE(t, vpcTf, "subnet_id")
	require.NoError(t, err, "failed to get subnet_id output")
	podsRangeName, err := terraform.OutputE(t, vpcTf, "pods_range_name")
	require.NoError(t, err, "failed to get pods_range_name output")
	servicesRangeName, err := terraform.OutputE(t, vpcTf, "services_range_name")
	require.NoError(t, err, "failed to get services_range_name output")

	t.Logf("VPC created: %s (network_id: %s)", vpcName, networkID)

	// -------------------------------------------------------------------------
	// Apply GKE with VPC outputs
	// -------------------------------------------------------------------------
	t.Log("Step 2: Creating GKE Autopilot cluster (this takes 15-20 minutes)...")

	// Create new GKE options with actual VPC values (avoid mutating original)
	gkeTfApply := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
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

	terraform.InitAndApply(t, gkeTfApply)

	clusterEndpoint, err := terraform.OutputE(t, gkeTfApply, "cluster_endpoint")
	require.NoError(t, err, "failed to get cluster_endpoint output")
	workloadIdentityPool, err := terraform.OutputE(t, gkeTfApply, "workload_identity_pool")
	require.NoError(t, err, "failed to get workload_identity_pool output")
	require.NotEmpty(t, clusterEndpoint)
	require.Equal(t, fmt.Sprintf("%s.svc.id.goog", projectID), workloadIdentityPool)

	t.Logf("GKE cluster created: %s", clusterName)

	// -------------------------------------------------------------------------
	// Apply service account
	// -------------------------------------------------------------------------
	t.Log("Step 3: Creating service account...")
	terraform.InitAndApply(t, saTf)
	t.Logf("Service account created: %s", backupSAName)

	// -------------------------------------------------------------------------
	// Apply backup bucket
	// -------------------------------------------------------------------------
	t.Log("Step 4: Creating backup bucket...")
	terraform.InitAndApply(t, bucketTf)

	backupBucketURL, err := terraform.OutputE(t, bucketTf, "bucket_url")
	require.NoError(t, err, "failed to get bucket_url output")
	require.Equal(t, fmt.Sprintf("gs://%s", backupBucketName), backupBucketURL)
	t.Logf("Backup bucket created: %s", backupBucketName)

	// -------------------------------------------------------------------------
	// Step 5: Deploy Neo4j via App Layer Terraform
	// -------------------------------------------------------------------------
	t.Log("Step 5: Deploying Neo4j via app layer Terraform...")

	// Get service account resource name for WIF binding
	backupGSAEmail := fmt.Sprintf("%s@%s.iam.gserviceaccount.com", backupSAName, projectID)
	backupGSAName := fmt.Sprintf("projects/%s/serviceAccounts/%s", projectID, backupGSAEmail)

	neo4jInstanceName := fmt.Sprintf("neo4j-%s", suffix)
	testPassword := fmt.Sprintf("test-pwd-%s", random.UniqueId())

	appDir := testhelpers.CopyAppModuleToTemp(t, "neo4j/test")

	appTf := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    appDir,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_id":             projectID,
			"region":                 region,
			"cluster_name":           clusterName,
			"cluster_location":       region,
			"workload_identity_pool": workloadIdentityPool,
			"backup_gsa_email":       backupGSAEmail,
			"backup_gsa_name":        backupGSAName,
			"backup_bucket_url":      backupBucketURL,
			"neo4j_password":         testPassword,
			"neo4j_instance_name":    neo4jInstanceName,
			"neo4j_namespace":        "neo4j",
		},
		NoColor: true,
	})

	// Register cleanup for app layer (runs before bucket/SA/GKE/VPC due to LIFO)
	testhelpers.DeferredTerraformCleanup(t, appTf)

	terraform.InitAndApply(t, appTf)

	// Verify app layer outputs
	namespace, err := terraform.OutputE(t, appTf, "namespace")
	require.NoError(t, err, "failed to get namespace output")
	require.Equal(t, "neo4j", namespace)

	wiBindingMember, err := terraform.OutputE(t, appTf, "wi_binding_member")
	require.NoError(t, err, "failed to get wi_binding_member output")
	require.Contains(t, wiBindingMember, "neo4j-backup")

	defaultDenyPolicy, err := terraform.OutputE(t, appTf, "network_policy_default_deny")
	require.NoError(t, err, "failed to get network_policy_default_deny output")
	require.Equal(t, "default-deny-all", defaultDenyPolicy)

	allowNeo4jPolicy, err := terraform.OutputE(t, appTf, "network_policy_allow_neo4j")
	require.NoError(t, err, "failed to get network_policy_allow_neo4j output")
	require.Equal(t, "allow-neo4j", allowNeo4jPolicy)

	t.Logf("Neo4j app layer deployed: instance=%s, namespace=%s", neo4jInstanceName, namespace)

	// -------------------------------------------------------------------------
	// Step 6: Set up kubeconfig and wait for Neo4j
	// -------------------------------------------------------------------------
	t.Log("Step 6: Waiting for Neo4j pod to be ready...")
	kubeconfigPath := setupKubeconfig(t, projectID, region, clusterName)
	kubectlOptionsNs := k8s.NewKubectlOptions("", kubeconfigPath, "neo4j")
	waitForNeo4jReady(t, kubectlOptionsNs, neo4jInstanceName, 10*time.Minute)
	t.Log("Neo4j pod is ready")

	// -------------------------------------------------------------------------
	// Step 7: Verify Neo4j is running
	// -------------------------------------------------------------------------
	t.Log("Step 7: Verifying Neo4j is running...")
	verifyNeo4jRunning(t, kubectlOptionsNs, neo4jInstanceName)

	// Additional verification: check NetworkPolicies exist via kubectl
	t.Log("Step 7b: Verifying NetworkPolicies via kubectl...")
	policies, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptionsNs, "get", "networkpolicy",
		"-o", "jsonpath={.items[*].metadata.name}")
	require.NoError(t, err)
	require.Contains(t, policies, "default-deny-all")
	require.Contains(t, policies, "allow-neo4j")
	t.Logf("NetworkPolicies verified: %s", policies)

	t.Log("Neo4j full deployment test PASSED!")
}

// setupKubeconfig generates a kubeconfig for the GKE cluster.
func setupKubeconfig(t *testing.T, projectID, region, clusterName string) string {
	t.Helper()

	kubeconfigPath := filepath.Join(t.TempDir(), "kubeconfig")

	cmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"container", "clusters", "get-credentials", clusterName,
			"--region", region,
			"--project", projectID,
		},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	require.NoError(t, shell.RunCommandE(t, cmd))

	return kubeconfigPath
}

// waitForNeo4jReady waits for the Neo4j StatefulSet pod to be ready.
func waitForNeo4jReady(t *testing.T, options *k8s.KubectlOptions, releaseName string, timeout time.Duration) {
	t.Helper()

	podName := fmt.Sprintf("%s-0", releaseName)
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		// Check if pod exists and is running
		out, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "pod", podName,
			"-o", "jsonpath={.status.phase}")
		if err == nil && strings.TrimSpace(out) == "Running" {
			// Check container readiness
			ready, _ := k8s.RunKubectlAndGetOutputE(t, options, "get", "pod", podName,
				"-o", "jsonpath={.status.conditions[?(@.type=='Ready')].status}")
			if strings.TrimSpace(ready) == "True" {
				return
			}
		}
		time.Sleep(30 * time.Second)
		t.Logf("Waiting for Neo4j pod %s to be ready...", podName)
	}

	// On timeout, get pod status for debugging
	status, _ := k8s.RunKubectlAndGetOutputE(t, options, "describe", "pod", podName)
	t.Logf("Pod status on timeout:\n%s", status)

	require.FailNow(t, "Timeout waiting for Neo4j pod to be ready")
}

// verifyNeo4jRunning verifies Neo4j is running by checking pod status and logs.
func verifyNeo4jRunning(t *testing.T, options *k8s.KubectlOptions, releaseName string) {
	t.Helper()

	podName := fmt.Sprintf("%s-0", releaseName)

	// Check pod is running
	out, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "pod", podName,
		"-o", "jsonpath={.status.phase}")
	require.NoError(t, err)
	require.Equal(t, "Running", strings.TrimSpace(out))

	// Check logs for successful startup
	logs, err := k8s.RunKubectlAndGetOutputE(t, options, "logs", podName, "--tail=100")
	require.NoError(t, err)
	require.Contains(t, strings.ToLower(logs), "started", "Neo4j logs should indicate successful startup")

	// Verify services exist
	// Neo4j Helm chart uses "app" label (set to neo4j.name value), not app.kubernetes.io/instance
	services, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "svc",
		"-l", fmt.Sprintf("app=%s", releaseName),
		"-o", "jsonpath={.items[*].metadata.name}")
	require.NoError(t, err)
	require.NotEmpty(t, services, "Neo4j services should exist")

	t.Logf("Neo4j services found: %s", services)
}
