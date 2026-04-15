output "instance_public_ip" {
  description = "Adresse IP publique réservée de l'instance Minecraft"
  value       = module.compute.public_ip
}

output "minecraft_connect" {
  description = "Adresse de connexion Minecraft (à saisir dans le client)"
  value       = "${module.compute.public_ip}:25565"
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "ssh ubuntu@${module.compute.public_ip}"
}

output "tailscale_hostname" {
  description = "Hostname Tailscale de l'instance"
  value       = "minecraft-oci"
}
