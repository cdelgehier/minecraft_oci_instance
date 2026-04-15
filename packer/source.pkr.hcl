source "oracle-oci" "minecraft_arm64" {
  # ── Auth — lit ~/.oci/config profil DEFAULT (access_cfg_file_account défaut) ──
  region = var.region

  # ── Target ───────────────────────────────────────────────────────────────────
  availability_domain = var.availability_domain
  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid

  # ── Shape ARM64 (Ampere A1.Flex) ─────────────────────────────────────────────
  shape = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  # ── Image de base : Ubuntu 24.04 LTS ARM64 ───────────────────────────────────
  base_image_filter {
    operating_system         = "Canonical Ubuntu"
    operating_system_version = "24.04"
    display_name_search      = "^Canonical-Ubuntu-24.04-aarch64"
  }

  # ── Image résultante ─────────────────────────────────────────────────────────
  image_name = local.image_name

  # ── SSH pour provisioning ────────────────────────────────────────────────────
  ssh_username = "ubuntu"
}
