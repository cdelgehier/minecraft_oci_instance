#!/usr/bin/env bash
# Installe uv + ansible-core dans un venv isolé pour le provisioning Packer.
# Inspiré de cycloid-ami/files/add_temp_ansible.sh, mais utilise uv au lieu de pip.
set -eux -o pipefail

PROVISIONING_DIR="/tmp/provisioning"
VENV_DIR="${PROVISIONING_DIR}/venv"

# ── Installer uv ─────────────────────────────────────────────────────────────
export HOME=/home/ubuntu
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="${HOME}/.local/bin:${PATH}"

# ── Créer le venv et installer ansible-core depuis pyproject.toml ─────────────
uv venv "${VENV_DIR}" --python 3.12
uv pip install \
  --python "${VENV_DIR}/bin/python" \
  --requirement "${PROVISIONING_DIR}/pyproject.toml"

echo "✓ ansible-core: $(${VENV_DIR}/bin/ansible --version | head -1)"
