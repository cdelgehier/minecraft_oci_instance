output "world_volume_id" {
  description = "OCID du volume bloc monde Minecraft"
  value       = oci_core_volume.world.id
}

output "backup_bucket_name" {
  description = "Nom du bucket OCI Object Storage pour les backups restic"
  value       = oci_objectstorage_bucket.backup.name
}

output "backup_bucket_namespace" {
  description = "Namespace OCI Object Storage"
  value       = oci_objectstorage_bucket.backup.namespace
}
