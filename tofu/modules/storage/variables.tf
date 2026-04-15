variable "compartment_ocid" {
  description = "OCID du compartment Minecraft"
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain OCI"
  type        = string
}

variable "world_volume_size_gb" {
  description = "Taille du volume monde en GB"
  type        = number
  default     = 100
}

variable "object_storage_namespace" {
  description = "Namespace OCI Object Storage (auto-découvert)"
  type        = string
}

variable "tags" {
  description = "Tags communs à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
