variable "vault_namespace" {
  type        = string
  description = "The vault namespace to create the policy in"
}

variable "client_namespace" {
  type        = string
  description = "The vault namespace to read client entity id from"
}

variable "client_entity_name" {
  type        = string
  description = "client entity name from client namespace"
}
