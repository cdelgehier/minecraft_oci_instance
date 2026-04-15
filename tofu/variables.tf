# ── OCIDs (terraform.tfvars) ──────────────────────────────────────────────────

variable "compartment_ocid" {
  description = "OCID du compartment Minecraft"
  type        = string
}

variable "subnet_ocid" {
  description = "OCID du subnet public existant"
  type        = string
}

# ── Infrastructure (terraform.tfvars) ─────────────────────────────────────────

variable "region" {
  description = "OCI home region"
  type        = string
}

variable "availability_domain" {
  description = "OCI Availability Domain"
  type        = string
}

variable "instance_ocpus" {
  description = "Nombre d'OCPUs — Always Free max : 4"
  type        = number
  default     = 4

  validation {
    condition     = var.instance_ocpus <= 4
    error_message = "Always Free tier : max 4 OCPUs."
  }
}

variable "instance_memory_gb" {
  description = "RAM en GB — Always Free max : 24"
  type        = number
  default     = 24

  validation {
    condition     = var.instance_memory_gb <= 24
    error_message = "Always Free tier : max 24 GB RAM."
  }
}

variable "boot_volume_size_gb" {
  description = "Taille du volume de boot en GB"
  type        = number
  default     = 50
}

variable "world_volume_size_gb" {
  description = "Taille du block volume pour les données du monde Minecraft"
  type        = number
  default     = 100
}

variable "minecraft_image_ocid" {
  description = "OCID de l'image Packer Minecraft (jq -r '.builds[-1].artifact_id' packer/manifest.json)"
  type        = string
  default     = ""
}

# ── Secrets (secrets.tfvars — gitignored) ─────────────────────────────────────

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
  description = "OCI Customer Secret Key — Access Key (pour restic + backend state)"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "OCI Customer Secret Key — Secret Key (pour restic + backend state)"
  type        = string
  sensitive   = true
}
