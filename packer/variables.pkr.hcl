# ── OCI Target (minecraft.pkrvars.hcl) ───────────────────────────────────────
variable "compartment_ocid" {
  description = "OCID du compartiment cible pour le build"
  type        = string
}

variable "subnet_ocid" {
  description = "OCID du subnet pour l'instance de build temporaire"
  type        = string
}

# ── Configuration (minecraft.pkrvars.hcl) ────────────────────────────────────
variable "key_file" {
  description = "Chemin vers la clé privée OCI (utilisé par config_file_profile=DEFAULT)"
  type        = string
  default     = "~/.oci/perso.pem"
}

variable "region" {
  description = "Région OCI"
  type        = string
  default     = "eu-marseille-1"
}

variable "availability_domain" {
  description = "Availability Domain (oci iam availability-domain list)"
  type        = string
}

variable "minecraft_version" {
  description = "Version de Minecraft / Paper MC"
  type        = string
  default     = "1.21.11"
}

variable "instance_ocpus" {
  description = "OCPUs pour l'instance de build Packer"
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "RAM en Go pour l'instance de build Packer"
  type        = number
  default     = 8
}
