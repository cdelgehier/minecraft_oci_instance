# ── Provider OCI — lit ~/.oci/config profil DEFAULT ──────────────────────────
provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.region
}

# ── Namespace Object Storage (auto-découvert) ─────────────────────────────────
data "oci_objectstorage_namespace" "current" {}

# ── Security List — toutes les règles réseau OCI ──────────────────────────────
resource "oci_core_security_list" "minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.oci_core_subnet.minecraft.vcn_id
  display_name   = "minecraft-security-list"
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Minecraft Java TCP"
    tcp_options {
      min = 25565
      max = 25565
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    description = "Minecraft Bedrock UDP (Geyser clone-remote-port)"
    udp_options {
      min = 25565
      max = 25565
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    description = "Minecraft Bedrock UDP (Geyser fallback)"
    udp_options {
      min = 19132
      max = 19132
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP Path MTU"
    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Tout le trafic sortant"
  }
}

data "oci_core_subnet" "minecraft" {
  subnet_id = var.subnet_ocid
}

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
