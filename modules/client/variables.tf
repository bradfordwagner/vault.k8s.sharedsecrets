variable "vault_namespace" {
  type        = string
  description = "The vault namespace to create the policy in"
}

variable "client_test_kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace to create the client test pod in"
}

variable "client_entity_name" {
  type        = string
  description = "client entity name from client namespace"
}
