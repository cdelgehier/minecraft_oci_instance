# ── Provider OCI — lit ~/.oci/config profil DEFAULT ──────────────────────────
provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.region
}

# ── Namespace Object Storage (auto-découvert) ─────────────────────────────────
data "oci_objectstorage_namespace" "current" {}

# ── Modules ───────────────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

  compartment_ocid         = var.compartment_ocid
  availability_domain      = var.availability_domain
  world_volume_size_gb     = var.world_volume_size_gb
  object_storage_namespace = data.oci_objectstorage_namespace.current.namespace
  tags                     = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_id           = var.subnet_ocid
  image_ocid          = var.minecraft_image_ocid
  instance_ocpus      = var.instance_ocpus
  instance_memory_gb  = var.instance_memory_gb
  boot_volume_size_gb = var.boot_volume_size_gb
  world_volume_id     = module.storage.world_volume_id

  ssh_public_key     = var.ssh_public_key
  rcon_password      = var.rcon_password
  tailscale_auth_key = var.tailscale_auth_key
  restic_password    = var.restic_password
  s3_access_key      = var.s3_access_key
  s3_secret_key      = var.s3_secret_key
  s3_endpoint        = "https://${data.oci_objectstorage_namespace.current.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"

  tags = local.common_tags
}
