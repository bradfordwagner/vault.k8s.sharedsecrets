# create a kv2 secrets engine
resource "vault_mount" "kv2_secrets" {
  namespace = var.vault_namespace
  path      = "kv2"
  type      = "kv-v2"
}

resource "vault_generic_secret" "shared_secret" {
  path      = "${vault_mount.kv2_secrets.path}/shared"
  namespace = var.vault_namespace
  data_json = <<EOT
{
  "sir": "sharesalot"
}
EOT
}

# create vault token policy to access kv2/shared
resource "vault_policy" "shared_policy" {
  namespace = var.vault_namespace
  name      = "shared_policy"
  policy    = <<EOT
path "${vault_mount.kv2_secrets.path}/data/shared" {
  capabilities = ["read"]
}
EOT
}

# group
resource "vault_identity_group" "shared_access_group" {
  namespace = var.vault_namespace
  name      = "shared_access_group"
  policies  = [vault_policy.shared_policy.name]
  type      = "internal"
}

data "vault_identity_entity" "client_entity" {
  entity_name = "client_entity" // i got lazy here hard coded instead of threaded
  namespace   = var.client_namespace
}

resource "vault_identity_group_member_entity_ids" "shared_access_group_members" {
  namespace         = var.vault_namespace
  member_entity_ids = [data.vault_identity_entity.client_entity.id]
  group_id          = vault_identity_group.shared_access_group.id
  exclusive         = false
}
