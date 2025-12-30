provider "google" {
  project = var.project_id
}

# Use the two-variant pattern so prevent_destroy can be toggled per environment.
resource "google_service_account" "service_account_protected" {
  for_each     = var.prevent_destroy_service_accounts ? local.service_accounts : {}
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
  disabled     = each.value.disabled

  lifecycle { prevent_destroy = true }
}

resource "google_service_account" "service_account_unprotected" {
  for_each     = var.prevent_destroy_service_accounts ? {} : local.service_accounts
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
  disabled     = each.value.disabled

  lifecycle { prevent_destroy = false }
}

# Whichever variant exists (handy for outputs)
locals {
  _sa = var.prevent_destroy_service_accounts ? google_service_account.service_account_protected : google_service_account.service_account_unprotected
}