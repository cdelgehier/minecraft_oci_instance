variable "compartment_ocid" {
  description = "OCID du compartment Minecraft"
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain OCI"
  type        = string
}

variable "subnet_id" {
  description = "OCID du subnet public"
  type        = string
}

variable "image_ocid" {
  description = "OCID de l'image Packer Minecraft"
  type        = string
}

variable "instance_ocpus" {
  description = "Nombre d'OCPUs (Always Free max : 4)"
  type        = number
  default     = 4
}

variable "instance_memory_gb" {
  description = "RAM en GB (Always Free max : 24)"
  type        = number
  default     = 24
}

variable "boot_volume_size_gb" {
  description = "Taille du volume boot en GB"
  type        = number
  default     = 50
}

variable "world_volume_id" {
  description = "OCID du volume bloc monde Minecraft"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé SSH publique pour l'accès à l'instance"
  type        = string
  sensitive   = true
}

variable "rcon_password" {
  description = "Mot de passe RCON Minecraft"
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Clé d'auth Tailscale (ephemeral ou reusable)"
  type        = string
  sensitive   = true
}

variable "restic_password" {
  description = "Mot de passe de chiffrement du repo restic"
  type        = string
  sensitive   = true
}

variable "s3_access_key" {
  description = "Access key OCI Customer Secret Key (pour restic backup)"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Secret key OCI Customer Secret Key (pour restic backup)"
  type        = string
  sensitive   = true
}

variable "s3_endpoint" {
  description = "Endpoint S3-compatible OCI Object Storage"
  type        = string
}

variable "tags" {
  description = "Tags communs à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
