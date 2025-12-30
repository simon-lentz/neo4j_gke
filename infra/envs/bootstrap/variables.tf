variable "project_id" { type = string }
variable "bucket_location" { type = string } # e.g. "us-central1", "US"
variable "kms_location" { type = string }    # often same as bucket_location (or inferred by module)
variable "bucket_name" {
  type    = string
  default = null
}
variable "bucket_versioning" {
  type    = bool
  default = false
}
variable "retention_period_seconds" {
  type    = number
  default = null
}
variable "rotation_period" {
  type    = number
  default = 2592000
} # 30d recommended
variable "labels" {
  type = map(string)
  default = {
    component = "bootstrap"
  }
}
variable "randomize_bucket_name" {
  type    = bool
  default = true
}
variable "force_destroy" {
  type    = bool
  default = false
}