# Tests unitaires du module compute.
# Exécutés en mode plan uniquement — aucun compte OCI requis.
# Lance avec : task tofu:test

mock_provider "oci" {}

variables {
  compartment_ocid    = "ocid1.compartment.oc1..aaaamockcompartment"
  availability_domain = "TEST:EU-TEST-1-AD-1"
  subnet_id           = "ocid1.subnet.oc1..aaaamocksubnet"
  image_ocid          = "ocid1.image.oc1..aaaamockimage"
  world_volume_id     = "ocid1.volume.oc1..aaaamockvolume"
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAImock mock@test"
  rcon_password       = "mock_rcon_password"
  tailscale_auth_key  = "tskey-auth-mockXXXXXXXXXXXX-XXXXXXXXXXXX"
  restic_password     = "mock_restic_password"
  s3_access_key       = "mock_s3_access_key"
  s3_secret_key       = "mock_s3_secret_key"
  s3_endpoint         = "https://mocknamespace.compat.objectstorage.eu-marseille-1.oraclecloud.com"
}

# ── Instance shape Always Free ────────────────────────────────────────────────

run "shape_always_free_arm" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_instance.minecraft.shape == "VM.Standard.A1.Flex"
    error_message = "Shape doit être VM.Standard.A1.Flex — seul shape ARM Always Free."
  }
}

run "ocpus_defaut_4" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_instance.minecraft.shape_config[0].ocpus == 4
    error_message = "OCPUs par défaut : 4 (max Always Free)."
  }
}

run "ram_defaut_24gb" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_instance.minecraft.shape_config[0].memory_in_gbs == 24
    error_message = "RAM par défaut : 24 GB (max Always Free)."
  }
}

# ── IP publique réservée ───────────────────────────────────────────────────────

run "ip_reservee_fixe" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_public_ip.reserved.lifetime == "RESERVED"
    error_message = "IP publique doit être RESERVED — ne doit pas changer après reboot."
  }
}

# ── Cloud-init contient les secrets ───────────────────────────────────────────

run "cloud_init_present" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_instance.minecraft.metadata["user_data"] != null
    error_message = "user_data (cloud-init) doit être défini dans les métadonnées de l'instance."
  }
}

# ── Attachement volume monde ──────────────────────────────────────────────────

run "attachement_paravirtualised" {
  command = plan

  module {
    source = "./modules/compute"
  }

  assert {
    condition     = oci_core_volume_attachment.world.attachment_type == "paravirtualized"
    error_message = "Volume monde : attachment_type doit être 'paravirtualized' (meilleure perf ARM)."
  }
}
