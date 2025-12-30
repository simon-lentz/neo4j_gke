terraform {
  backend "gcs" {
    prefix = "apps/neo4j/dev"
  }
}
