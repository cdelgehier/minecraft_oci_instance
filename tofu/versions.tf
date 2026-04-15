terraform {
  required_version = ">= 1.11.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.10"
    }
  }
}
