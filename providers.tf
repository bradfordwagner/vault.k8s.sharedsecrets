terraform {
  required_version = ">=1.5.7"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">=3.24.0"
    }
  }
}
