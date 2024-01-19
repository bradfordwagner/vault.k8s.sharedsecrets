# create kubernetes auth endpoint
resource "vault_auth_backend" "kubernetes_auth_endpoint" {
  provider  = vault
  namespace = var.vault_namespace
  type      = "kubernetes"
  path      = "kubernetes/client_cluster"
  tune {
    default_lease_ttl = "60s" # uses golang duration string
  }
}

# create a kv2 secrets engine
resource "vault_mount" "kv2_secrets" {
  namespace = var.vault_namespace
  path      = "kv2"
  type      = "kv-v2"
}

resource "vault_generic_secret" "smoke_test" {
  path      = "${vault_mount.kv2_secrets.path}/client"
  namespace = var.vault_namespace
  data_json = <<EOT
{
  "sir": "smokesalot"
}
EOT
}

resource "vault_identity_entity" "client_entity" {
  namespace = var.vault_namespace
  name      = var.client_entity_name
  metadata = {
    "namespace" = var.vault_namespace
  }
}

locals {
  test_values_yaml = yamldecode(file("./charts/testbed/values.yaml"))
  entity_sa_name   = local.test_values_yaml.service_account_name
  entity_role      = local.test_values_yaml.vault.role
}
resource "vault_identity_entity_alias" "client_entity_alias" {
  depends_on     = [vault_identity_entity.client_entity]
  namespace      = var.vault_namespace
  name           = "${var.client_test_kubernetes_namespace}/${local.entity_sa_name}"
  mount_accessor = vault_auth_backend.kubernetes_auth_endpoint.accessor
  canonical_id   = vault_identity_entity.client_entity.id
}

# bind role to service account + namespace + token policy
resource "vault_kubernetes_auth_backend_role" "smoke_test" {
  namespace                        = var.vault_namespace
  role_name                        = local.entity_role
  backend                          = vault_auth_backend.kubernetes_auth_endpoint.path
  bound_service_account_names      = [local.entity_sa_name]
  bound_service_account_namespaces = [var.client_test_kubernetes_namespace]
  token_policies = [
    vault_policy.client_policy.name,
  ]
  alias_name_source = "serviceaccount_name"
}

# create vault token policy to access kvs/client
resource "vault_policy" "client_policy" {
  namespace = var.vault_namespace
  name      = "client_policy"
  policy    = <<EOT
path "${vault_mount.kv2_secrets.path}/data/client" {
  capabilities = ["read"]
}
EOT
}
