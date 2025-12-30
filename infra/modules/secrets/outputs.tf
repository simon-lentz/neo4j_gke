output "secrets" {
  description = "Map of secret-key => secret details (id, name, secret_id)."
  value = {
    for k, s in google_secret_manager_secret.secrets : k => {
      id        = s.id
      name      = s.name
      secret_id = s.secret_id
    }
  }
}

output "secret_ids" {
  description = "Map of secret-key => secret_id for use in data sources."
  value = {
    for k, s in google_secret_manager_secret.secrets : k => s.secret_id
  }
}

output "secret_names" {
  description = "Map of secret-key => full resource name."
  value = {
    for k, s in google_secret_manager_secret.secrets : k => s.name
  }
}
