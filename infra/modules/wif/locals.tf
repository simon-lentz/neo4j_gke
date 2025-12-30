locals {
  base_attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.actor"            = "assertion.actor"
    "attribute.workflow"         = "assertion.workflow"
    "attribute.sha"              = "assertion.sha"
    "attribute.event_name"       = "assertion.event_name"
    "attribute.ref_type"         = "assertion.ref_type"
    "attribute.aud"              = "assertion.aud"
  }

  # repo: (attribute.repository == "a" || attribute.repository == "b")
  repo_cond = length(var.allowed_repositories) == 0 ? null : format("(%s)", join(" || ", [
    for r in sort(tolist(var.allowed_repositories)) :
    format("attribute.repository == %q", r)
  ]))

  # owner: (attribute.repository_owner == "acme" || ...)
  owner_cond = length(var.allowed_repository_owners) == 0 ? null : format("(%s)", join(" || ", [
    for o in sort(tolist(var.allowed_repository_owners)) :
    format("attribute.repository_owner == %q", o)
  ]))

  # refs: exact -> attribute.ref == "refs/heads/main"
  #       prefix -> startsWith(attribute.ref, "refs/heads/release/")
  ref_terms = [
    for ref in var.allowed_refs :
    endswith(ref, "/*")
    ? format("startsWith(attribute.ref, %q)", format("%s/", trimsuffix(ref, "/*")))
    : format("attribute.ref == %q", ref)
  ]
  ref_cond = length(local.ref_terms) == 0 ? null : format("(%s)", join(" || ", local.ref_terms))

  # aud: (attribute.aud == "value1" || attribute.aud == "value2")
  aud_cond = length(var.allowed_audiences) == 0 ? null : format("(%s)", join(" || ", [
    for a in sort(tolist(var.allowed_audiences)) :
    format("attribute.aud == %q", a)
  ]))

  # Final CEL: categories ANDed, options within a category ORed
  computed_attribute_condition = join(" && ", compact([
    local.repo_cond,
    local.owner_cond,
    local.ref_cond,
    local.aud_cond,
  ]))
}