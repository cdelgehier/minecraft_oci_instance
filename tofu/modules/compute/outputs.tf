output "instance_id" {
  description = "OCID de l'instance Minecraft"
  value       = oci_core_instance.minecraft.id
}

output "public_ip" {
  description = "Adresse IP publique réservée"
  value       = oci_core_public_ip.reserved.ip_address
}

output "private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = oci_core_instance.minecraft.private_ip
}
