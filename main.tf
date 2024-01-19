provider "vault" {}

locals {
  namespaces = {
    client = "client"
    shared = "shared"
  }

  client_entity_name = "client_entity"
}

# create a vault namespace called client
resource "vault_namespace" "namespaces" {
  for_each = local.namespaces
  path     = each.value
}

module "client" {
  depends_on                       = [vault_namespace.namespaces]
  source                           = "./modules/client"
  client_test_kubernetes_namespace = var.client_test_kubernetes_namespace
  vault_namespace                  = local.namespaces.client
  client_entity_name               = local.client_entity_name
}

module "shared" {
  depends_on         = [vault_namespace.namespaces, module.client]
  source             = "./modules/shared"
  vault_namespace    = local.namespaces.shared
  client_namespace   = local.namespaces.client
  client_entity_name = local.client_entity_name
}
