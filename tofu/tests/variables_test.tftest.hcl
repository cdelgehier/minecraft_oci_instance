# Tests des validations de variables du module racine.
# Vérifie que les contraintes Always Free sont bien appliquées.
# Exécutés en mode plan uniquement — aucun compte OCI requis.
# Lance avec : task tofu:test

mock_provider "oci" {
  mock_data "oci_objectstorage_namespace" {
    defaults = {
      namespace = "mocknamespace"
    }
  }
}

# Variables communes (valeurs valides par défaut)
variables {
  compartment_ocid     = "ocid1.compartment.oc1..aaaamockcompartment"
  subnet_ocid          = "ocid1.subnet.oc1..aaaamocksubnet"
  region               = "eu-marseille-1"
  availability_domain  = "TEST:EU-TEST-1-AD-1"
  minecraft_image_ocid = "ocid1.image.oc1..aaaamockimage"
  ssh_public_key       = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAImock mock@test"
  rcon_password        = "mock_rcon_password"
  tailscale_auth_key   = "tskey-auth-mock"
  restic_password      = "mock_restic"
  s3_access_key        = "mock_key"
  s3_secret_key        = "mock_secret"
}

# ── Validations Always Free ───────────────────────────────────────────────────

run "ocpus_depasse_limite_always_free" {
  command = plan

  variables {
    instance_ocpus = 8 # > 4 : doit déclencher une erreur de validation
  }

  expect_failures = [
    var.instance_ocpus,
  ]
}

run "ram_depasse_limite_always_free" {
  command = plan

  variables {
    instance_memory_gb = 48 # > 24 : doit déclencher une erreur de validation
  }

  expect_failures = [
    var.instance_memory_gb,
  ]
}

# ── Valeurs limites acceptées ─────────────────────────────────────────────────

run "ocpus_max_always_free_accepte" {
  command = plan

  variables {
    instance_ocpus = 4 # valeur max — doit passer sans erreur
  }

  assert {
    condition     = var.instance_ocpus == 4
    error_message = "4 OCPUs doit être accepté (limite Always Free exacte)."
  }
}

run "ram_max_always_free_accepte" {
  command = plan

  variables {
    instance_memory_gb = 24 # valeur max — doit passer sans erreur
  }

  assert {
    condition     = var.instance_memory_gb == 24
    error_message = "24 GB RAM doit être accepté (limite Always Free exacte)."
  }
}
