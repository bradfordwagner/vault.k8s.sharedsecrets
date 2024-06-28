

# setup approle auth
resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "kauth" {
  backend = vault_auth_backend.approle.path
  role_name = "kauth"
  token_policies = ["kauth"]
  token_explicit_max_ttl = 600 # 10 minutes
}

# # create vault token policy to access kvs/client
resource "vault_policy" "kauth" {
  name      = "kauth"
  policy    = <<EOT
path "client/kubernetes/client_cluster/config" {
  capabilities = ["read"]
}
path "client/kubernetes/client_cluster/creds/kauth-approle" {
  capabilities = ["update"]
}
EOT
}
