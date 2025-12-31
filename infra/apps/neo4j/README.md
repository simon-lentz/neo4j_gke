# Neo4j Application

This directory contains the OpenTofu configuration for deploying Neo4j Enterprise to GKE Autopilot clusters.

## Overview

The Neo4j application layer deploys on top of the platform infrastructure (`infra/envs/`). It provisions:

- Kubernetes namespace with environment labels
- Service account with Workload Identity for GCS backups
- NetworkPolicies (default-deny + allow Neo4j traffic)
- Neo4j Enterprise via Helm chart

## Directory Structure

```
neo4j/
├── README.md           # This file
└── dev/                # Dev environment
    ├── backend.tf      # GCS backend (prefix: apps/neo4j/dev)
    ├── providers.tf    # Google, Kubernetes, Helm providers
    ├── main.tf         # Resources: namespace, KSA, NetworkPolicy, Helm
    ├── variables.tf    # Input variables
    ├── outputs.tf      # Deployment outputs
    ├── versions.tf     # Provider version constraints
    └── values/
        └── neo4j.yaml  # Helm chart values
```

## Prerequisites

1. **Platform layer deployed** - The corresponding environment in `infra/envs/` must be applied first:
   ```bash
   cd infra/envs/dev
   tofu apply
   ```

2. **Neo4j password set** - Add a secret version to the password secret created by the platform layer:
   ```bash
   echo -n "your-secure-password" | gcloud secrets versions add neo4j-admin-password-dev --data-file=-
   ```

3. **GCP authentication** - Ensure you have valid credentials:
   ```bash
   gcloud auth application-default login
   ```

## Deployment

### Dev Environment

```bash
cd infra/apps/neo4j/dev

# Initialize with backend
tofu init -backend-config="bucket=YOUR_STATE_BUCKET"

# Review changes
tofu plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="state_bucket=YOUR_STATE_BUCKET"

# Apply
tofu apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="state_bucket=YOUR_STATE_BUCKET"
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | `us-central1` |
| `state_bucket` | GCS bucket for platform state | (required) |
| `environment` | Environment name | `dev` |
| `neo4j_chart_version` | Neo4j Helm chart version | `5.26.0` |
| `neo4j_namespace` | Kubernetes namespace | `neo4j` |
| `neo4j_instance_name` | Neo4j instance name | `neo4j-dev` |
| `neo4j_storage_size` | Data volume size | `10Gi` |
| `enable_neo4j_browser` | Enable HTTP for Neo4j Browser | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `namespace` | Kubernetes namespace |
| `neo4j_instance_name` | Neo4j instance name |
| `neo4j_bolt_service` | Bolt protocol service name |
| `neo4j_bolt_port` | Bolt protocol port (7687) |
| `backup_ksa_name` | Backup service account name |
| `backup_bucket_url` | GCS backup bucket URL |
| `connection_info` | Connection details (URIs, username, password reference) |

## Connecting to Neo4j

After deployment, connect from within the cluster:

```bash
# Port-forward for local access
kubectl port-forward -n neo4j svc/neo4j-dev-lb-neo4j 7687:7687

# Connect with cypher-shell
cypher-shell -a bolt://localhost:7687 -u neo4j -p <password>
```

### Neo4j Browser (Web UI)

Access the Neo4j Browser for visual graph exploration and query development:

```bash
# Port-forward HTTP for browser access
kubectl port-forward -n neo4j svc/neo4j-dev-lb-neo4j 7474:7474

# Open in browser
open http://localhost:7474/browser
```

**Credentials:**

- **Username:** `neo4j`
- **Password:** Retrieved from Secret Manager (`neo4j-admin-password-dev`)

The Neo4j Browser provides:

- Visual graph exploration
- Cypher query editor with syntax highlighting
- Database schema visualization
- Query performance profiling

## Backups

The deployment creates a Kubernetes service account (`neo4j-backup`) with Workload Identity configured to write to the GCS backup bucket. To run a backup:

```bash
# From a pod with the neo4j-backup service account
neo4j-admin database backup \
  --to-path=gs://YOUR_BUCKET/backups/$(date +%Y%m%d) \
  neo4j
```

## Security

- **NetworkPolicies**: Default-deny policy blocks all traffic; explicit allow for Neo4j ports (7687, 7474) and egress for DNS/HTTPS
- **No external LoadBalancer**: Services are ClusterIP only (no public exposure)
- **Workload Identity**: Backup SA uses WIF instead of exported keys
- **Secret Manager**: Password stored in GCP Secret Manager, not in state

### Pod Security Context

The Helm values configure pod-level security hardening:

| Setting | Value | Purpose |
|---------|-------|---------|
| `runAsNonRoot` | `true` | Prevent running as root user |
| `runAsUser/runAsGroup` | `7474` | Standard Neo4j UID in official images |
| `fsGroup` | `7474` | Enable group access to persistent volumes |
| `seccompProfile` | `RuntimeDefault` | Apply default seccomp sandboxing |
| `allowPrivilegeEscalation` | `false` | Prevent container privilege escalation |
| `capabilities.drop` | `ALL` | Remove all Linux capabilities |

**Note:** `readOnlyRootFilesystem` is intentionally **not set to true** because Neo4j requires write access to:
- `/var/lib/neo4j/data` - Database files
- `/var/lib/neo4j/logs` - Query and transaction logs
- `/tmp` - Temporary files

**GKE Autopilot:** The cluster automatically enforces Pod Security Standards at the "restricted" profile level, providing additional security constraints beyond what's configured here.

## Production TLS Configuration

The dev environment uses permissive TLS settings for convenience. Production deployments must harden these settings:

1. **Enable TLS for Bolt connections:**
   ```yaml
   server.bolt.tls_level: "REQUIRED"
   ```

2. **Disable HTTP, enable HTTPS:**
   ```yaml
   server.http.enabled: "false"
   server.https.enabled: "true"
   ```

3. **Provision TLS certificates** using one of:
   - cert-manager with Let's Encrypt
   - Self-signed certificates for internal use
   - Externally provisioned certificates

4. **Mount certificate secret** in Neo4j pod via Helm values:
   ```yaml
   ssl:
     bolt:
       privateKey:
         secretName: neo4j-tls
         subPath: tls.key
       publicCertificate:
         secretName: neo4j-tls
         subPath: tls.crt
   ```

See `dev/values/neo4j.yaml` for detailed comments on each TLS setting.

## Adding a New Environment

To add a production environment:

1. Copy the dev directory:
   ```bash
   cp -r dev/ prod/
   ```

2. Update `prod/backend.tf`:
   ```hcl
   terraform {
     backend "gcs" {
       prefix = "apps/neo4j/prod"
     }
   }
   ```

3. Update `prod/variables.tf` defaults:
   ```hcl
   variable "environment" {
     default = "prod"
   }

   variable "neo4j_instance_name" {
     default = "neo4j-prod"
   }

   variable "neo4j_storage_size" {
     default = "100Gi"  # Larger for prod
   }
   ```

4. Update `prod/values/neo4j.yaml` for production settings:
   - Enable TLS: `server.bolt.tls_level: "REQUIRED"`
   - Increase resources
   - Enable metrics if using Prometheus

5. Deploy the platform layer for prod first (`infra/envs/prod/`), then apply the app layer.
