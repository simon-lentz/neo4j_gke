output "service_accounts" {
  description = "Map of service-account key -> details (email, account_id, name, unique_id)."
  value = {
    for k, r in local._sa :
    k => {
      email      = r.email
      account_id = r.account_id
      name       = r.name
      unique_id  = r.unique_id
    }
  }
}