package test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	testStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

// repoRoot locates the repository root by walking parent directories until a
// .git directory is discovered. It honours the NEO4J_GKE_REPO_ROOT override so
// callers can short-circuit discovery if desired.
func repoRoot(t *testing.T) string {
	t.Helper()

	if override := strings.TrimSpace(os.Getenv("NEO4J_GKE_REPO_ROOT")); override != "" {
		return override
	}

	dir, err := os.Getwd()
	require.NoError(t, err)

	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}

		parent := filepath.Dir(dir)
		require.NotEqualf(t, parent, dir, "could not locate repository root from %s; set NEO4J_GKE_REPO_ROOT", dir)
		dir = parent
	}
}

// copyModuleToTemp mirrors the previous behaviour of CopyTerraformFolderToTemp
// but with paths relative to the repository root now that the tests live under
// infrastructure/test/.
func copyModuleToTemp(t *testing.T, moduleRelativePath string) string {
	t.Helper()

	return testStructure.CopyTerraformFolderToTemp(
		t,
		repoRoot(t),
		filepath.Join("infra", "modules", moduleRelativePath),
	)
}
