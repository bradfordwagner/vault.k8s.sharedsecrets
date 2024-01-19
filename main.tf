provider "vault" {}


locals {
  namespaces = {
    client = "client"
    shared = "shared"
  }
}

# create a vault namespace called client
resource "vault_namespace" "namespaces" {
  for_each = local.namespaces
  path     = each.value
}
