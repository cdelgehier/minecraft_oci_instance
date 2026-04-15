# Tests unitaires du module storage.
# Exécutés en mode plan uniquement — aucun compte OCI requis.
# Lance avec : task tofu:test

mock_provider "oci" {}

variables {
  compartment_ocid         = "ocid1.compartment.oc1..aaaamockcompartment"
  availability_domain      = "TEST:EU-TEST-1-AD-1"
  object_storage_namespace = "mocknamespace"
}

# ── Volume monde ──────────────────────────────────────────────────────────────

run "volume_taille_defaut_100gb" {
  command = plan

  module {
    source = "./modules/storage"
  }

  assert {
    # size_in_gbs est de type string dans le provider OCI (ex: "100")
    condition     = tonumber(oci_core_volume.world.size_in_gbs) == 100
    error_message = "Volume monde : taille par défaut doit être 100 GB."
  }
}

run "volume_taille_custom" {
  command = plan

  module {
    source = "./modules/storage"
  }

  variables {
    world_volume_size_gb = 150
  }

  assert {
    condition     = tonumber(oci_core_volume.world.size_in_gbs) == 150
    error_message = "Volume monde : la taille passée en variable doit être respectée."
  }
}

run "volume_display_name" {
  command = plan

  module {
    source = "./modules/storage"
  }

  assert {
    condition     = oci_core_volume.world.display_name == "minecraft-world"
    error_message = "Volume monde : display_name doit être 'minecraft-world'."
  }
}

# ── Bucket backup ─────────────────────────────────────────────────────────────

run "bucket_acces_prive" {
  command = plan

  module {
    source = "./modules/storage"
  }

  assert {
    condition     = oci_objectstorage_bucket.backup.access_type == "NoPublicAccess"
    error_message = "Bucket backup : doit être privé (NoPublicAccess) — jamais public."
  }
}

run "bucket_nom" {
  command = plan

  module {
    source = "./modules/storage"
  }

  assert {
    condition     = oci_objectstorage_bucket.backup.name == "minecraft-backup"
    error_message = "Bucket backup : nom doit être 'minecraft-backup'."
  }
}
