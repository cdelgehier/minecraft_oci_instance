build {
  name    = "minecraft-server"
  sources = ["source.oracle-oci.minecraft_arm64"]

  # ── 1. Créer le répertoire de provisioning ───────────────────────────────
  provisioner "shell" {
    inline = ["mkdir -p /tmp/provisioning/files"]
  }

  # ── 2. Uploader les fichiers Ansible et pyproject.toml ───────────────────
  provisioner "file" {
    source      = "./files/"
    destination = "/tmp/provisioning/files/"
  }

  provisioner "file" {
    source      = "./pyproject.toml"
    destination = "/tmp/provisioning/pyproject.toml"
  }

  # ── 3. Installer uv + ansible-core via pyproject.toml ────────────────────
  provisioner "shell" {
    script = "./files/add_temp_ansible.sh"
  }

  # ── 4. Exécuter le playbook Ansible ──────────────────────────────────────
  provisioner "ansible-local" {
    playbook_file           = "./files/minecraft_install.yml"
    galaxy_file             = "./files/requirements.yml"
    command                 = "/tmp/provisioning/venv/bin/ansible-playbook"
    galaxy_command          = "/tmp/provisioning/venv/bin/ansible-galaxy"
    staging_directory       = "/tmp/provisioning"
    clean_staging_directory = false # nettoyé par remove_temp_ansible.sh
    galaxy_force_install    = true
    extra_arguments = [
      "-v",
      "--extra-vars", "ansible_python_interpreter=/tmp/provisioning/venv/bin/python",
      "--extra-vars", "minecraft_version=${var.minecraft_version}",
    ]
  }

  # ── 5. Nettoyer uv, venv, ansible ────────────────────────────────────────
  provisioner "shell" {
    script = "./files/remove_temp_ansible.sh"
  }

  # ── Manifest pour récupérer l'OCID de l'image dans le pipeline ───────────
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
