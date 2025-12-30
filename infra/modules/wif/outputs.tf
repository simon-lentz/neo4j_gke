output "pool_id" { value = local._pool.workload_identity_pool_id }
output "pool_name" { value = local._pool.name }
output "provider_name" { value = local._provider.name }

output "principalset_repository" {
  description = "Map <repo> -> principalSet URI for attribute.repository."
  value = {
    for r in var.allowed_repositories :
    r => "principalSet://iam.googleapis.com/${local._pool.name}/attribute.repository/${r}"
  }
}

output "principalset_owner" {
  description = "Map <owner> -> principalSet URI for attribute.repository_owner."
  value = {
    for o in var.allowed_repository_owners :
    o => "principalSet://iam.googleapis.com/${local._pool.name}/attribute.repository_owner/${o}"
  }
}