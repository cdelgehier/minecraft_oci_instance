#!/usr/bin/env bash
# Nettoie les artefacts temporaires du provisioning Packer.
set -eux -o pipefail

# uv et ses caches
rm -rf /home/ubuntu/.local/share/uv
rm -rf /home/ubuntu/.local/bin/uv
rm -rf /home/ubuntu/.cache/uv

# Ansible cache
rm -rf /home/ubuntu/.ansible
sudo rm -rf /root/.ansible

# Répertoire de provisioning
rm -rf /tmp/provisioning
