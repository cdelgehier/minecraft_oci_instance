#cloud-config

# Secrets injectés par OpenTofu via templatefile().
# Variables Tofu : rcon_password, tailscale_auth_key, etc.
# Variables bash : echappees avec $$ (ex: $$DEVICE devient $DEVICE dans l'OS).

write_files:
  # Mot de passe RCON — lu par minecraft-metrics.sh et minecraft-backup.sh
  - path: /etc/minecraft/rcon.password
    content: "${rcon_password}"
    permissions: '0400'
    owner: root:root

  # Credentials restic + OCI S3 pour les backups
  - path: /etc/minecraft/backup.env
    content: |
      RESTIC_REPOSITORY=s3:${s3_endpoint}/minecraft-backup
      RESTIC_PASSWORD=${restic_password}
      AWS_ACCESS_KEY_ID=${s3_access_key}
      AWS_SECRET_ACCESS_KEY=${s3_secret_key}
    permissions: '0400'
    owner: root:root

runcmd:
  # ── 1. Sauvegarder les defaults Packer avant de monter le volume ──────────────
  # /opt/minecraft/server/ contient eula.txt + server.properties (baked dans l'image)
  - cp -rp /opt/minecraft/server /opt/minecraft/defaults

  # ── 2. Monter le volume monde (paravirtualized = /dev/sdb) ───────────────────
  - |
    DEVICE="/dev/sdb"
    for i in $(seq 1 30); do
      [ -b "$DEVICE" ] && break
      sleep 2
    done
    if ! blkid "$DEVICE" | grep -q ext4; then
      mkfs.ext4 -L minecraft-world "$DEVICE"
    fi
    udevadm settle
    UUID=$(blkid -s UUID -o value "$DEVICE")
    echo "UUID=$UUID /opt/minecraft/server ext4 defaults,nofail,_netdev 0 2" >> /etc/fstab
    systemctl daemon-reload
    mount /opt/minecraft/server

  # ── 3. Premier boot : peupler le volume depuis les defaults Packer ────────────
  - |
    if [ -z "$(ls -A /opt/minecraft/server 2>/dev/null | grep -v lost+found)" ]; then
      cp -rp /opt/minecraft/defaults/. /opt/minecraft/server/
    fi
    chown -R minecraft:minecraft /opt/minecraft/server

  # ── 4. Injecter le mot de passe RCON dans server.properties ──────────────────
  - |
    RCON_PASS=$(cat /etc/minecraft/rcon.password)
    sed -i "s/RCON_PASSWORD_PLACEHOLDER/$RCON_PASS/" /opt/minecraft/server/server.properties
    chmod 0640 /opt/minecraft/server/server.properties
    chown minecraft:minecraft /opt/minecraft/server/server.properties

  # ── 5. Rejoindre le réseau Tailscale ─────────────────────────────────────────
  - tailscale up --auth-key "${tailscale_auth_key}" --hostname "minecraft-oci" --ssh --accept-routes

  # ── 6. Initialiser le repo restic (idempotent) ────────────────────────────────
  - |
    set -a && . /etc/minecraft/backup.env && set +a
    restic snapshots 2>/dev/null || restic init

  # ── 7. Démarrer les services ──────────────────────────────────────────────────
  - systemctl enable --now minecraft
  - systemctl enable --now minecraft-backup.timer
  - systemctl enable --now minecraft-metrics.timer
