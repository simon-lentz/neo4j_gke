resource "google_project_service" "serviceusage" {
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
}

resource "google_project_service" "enabled" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
  depends_on         = [google_project_service.serviceusage]
}