resource "oci_core_instance" "minecraft" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "minecraft-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = false
    display_name     = "minecraft-vnic"
    hostname_label   = "minecraft"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      rcon_password      = var.rcon_password
      tailscale_auth_key = var.tailscale_auth_key
      restic_password    = var.restic_password
      s3_access_key      = var.s3_access_key
      s3_secret_key      = var.s3_secret_key
      s3_endpoint        = var.s3_endpoint
    }))
  }

  freeform_tags = var.tags

  lifecycle {
    # Rebuild Packer ne force pas la recréation de l'instance
    ignore_changes = [source_details[0].source_id]
  }
}

# IP publique réservée — ne change pas après reboot ou recréation de l'instance.
resource "oci_core_public_ip" "reserved" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "minecraft-ip"
  private_ip_id  = data.oci_core_private_ips.minecraft_vnic.private_ips[0].id

  freeform_tags = var.tags
}

data "oci_core_vnic_attachments" "minecraft" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.minecraft.id
}

data "oci_core_private_ips" "minecraft_vnic" {
  vnic_id = data.oci_core_vnic_attachments.minecraft.vnic_attachments[0].vnic_id
}

# Attachement paravirtualisé du volume monde — apparaît comme /dev/sdb dans l'OS.
resource "oci_core_volume_attachment" "world" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.minecraft.id
  volume_id       = var.world_volume_id
  display_name    = "minecraft-world-attachment"
}
