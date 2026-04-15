locals {
  timestamp  = formatdate("YYYYMMDD-hhmmss", timestamp())
  image_name = "minecraft-server-24.04-${local.timestamp}"
}
