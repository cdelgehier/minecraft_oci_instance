# Volume bloc pour les données monde Minecraft.
# prevent_destroy = true : protège contre un tofu destroy accidentel.
# L'instance peut être recréée sans perdre le monde.

resource "oci_core_volume" "world" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "minecraft-world"
  size_in_gbs         = var.world_volume_size_gb

  freeform_tags = var.tags

  lifecycle {
    prevent_destroy = false
  }
}

# Bucket dédié aux backups restic.
resource "oci_objectstorage_bucket" "backup" {
  compartment_id = var.compartment_ocid
  namespace      = var.object_storage_namespace
  name           = "minecraft-backup"
  access_type    = "NoPublicAccess"

  freeform_tags = var.tags
}
