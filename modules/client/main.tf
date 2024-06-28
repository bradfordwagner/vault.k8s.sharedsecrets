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

################################################################
# create kubernetes backend
resource "vault_mount" "kubernetes_backends" {
  namespace                 = var.vault_namespace
  path                      = "kubernetes/client_cluster"
  type                      = "kubernetes"
  default_lease_ttl_seconds = 10 * 60 # 10 minutes
  max_lease_ttl_seconds     = 30 * 24 * 60 * 60 # 30 days
  options = {
    disable_local_ca_jwt = true
  }
}
resource "vault_kubernetes_secret_backend_role" "kauth_approle" {
  allowed_kubernetes_namespaces = ["default"]
  backend                       = vault_mount.kubernetes_backends.path
  generated_role_rules          = <<EOT
      rules:
      - apiGroups: ["*"]
        resources: [pods]
        verbs: [get, list]
EOT
  kubernetes_role_type = "Role"
  name = "kauth-approle"
  provider          = vault
  namespace         = var.vault_namespace
  token_default_ttl = 3600 # 1 hour
  token_max_ttl     = 28800 # 8 hours
  # add labels to kubernetes created resources in order to identify them
  # makes for easy cleanup if required
  extra_labels = {
    "managed-by" = "bw-vault"
  }
}
################################################################

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
