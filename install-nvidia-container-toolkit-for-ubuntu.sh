#!/usr/bin/env bash
#
# install-nvidia-container-toolkit-for-ubuntu.sh
#
# Installs and configures the NVIDIA Container Toolkit on an Ubuntu/Debian host,
# so that Docker containers (e.g. ollama-service) can access the host GPU.
#
# Requirements:
#   - An NVIDIA GPU with the proprietary driver already installed on the host
#     (verify with: nvidia-smi).
#   - Docker installed via APT (NOT via Snap — the snap version is sandboxed
#     and cannot access /dev/nvidia*).
#
# Usage:
#   chmod +x install-nvidia-container-toolkit.sh
#   ./install-nvidia-container-toolkit.sh
#
# After it finishes, validate manually with:
#   sudo docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi

set -euo pipefail

echo "==> [0/5] Running pre-flight checks..."

# Must NOT be a snap-based Docker install.
if command -v snap >/dev/null 2>&1 && snap list docker >/dev/null 2>&1; then
  echo "ERROR: Docker appears to be installed via Snap."
  echo "       The NVIDIA Container Toolkit cannot access the GPU under Snap's sandbox."
  echo "       Remove it (sudo snap remove --purge docker) and install Docker via APT first."
  exit 1
fi

# Host NVIDIA driver must be present.
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: 'nvidia-smi' not found on the host."
  echo "       Install the NVIDIA GPU driver first (e.g. sudo ubuntu-drivers install), then reboot."
  exit 1
fi

echo "    Host GPU detected:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true
echo

# If the toolkit is already installed, ask whether to reinstall.
if command -v nvidia-ctk >/dev/null 2>&1; then
  echo "NOTICE: The NVIDIA Container Toolkit already appears to be installed:"
  echo "        $(nvidia-ctk --version | head -n 1)"
  echo
  read -r -p "Reinstall / reconfigure anyway? [y/N] " REPLY
  case "$REPLY" in
    [yY]|[yY][eE][sS])
      echo "    Proceeding with reinstall..."
      echo
      ;;
    *)
      echo "    Skipping installation. Nothing to do."
      echo
      echo "    To validate GPU access inside a container, run:"
      echo "      sudo docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi"
      exit 0
      ;;
  esac
fi

echo "==> [1/5] Adding NVIDIA Container Toolkit repository and GPG key..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

echo "==> [2/5] Updating package lists and installing nvidia-container-toolkit..."
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "==> [3/5] Configuring the Docker runtime (updates /etc/docker/daemon.json)..."
sudo nvidia-ctk runtime configure --runtime=docker

echo "==> [4/5] Restarting the Docker daemon..."
sudo systemctl restart docker

echo "==> [5/5] Verifying nvidia-ctk is available..."
if command -v nvidia-ctk >/dev/null 2>&1; then
  nvidia-ctk --version
else
  echo "WARNING: nvidia-ctk not found on PATH after install. Check the steps above."
  exit 1
fi

echo
echo "==> Done. The NVIDIA Container Toolkit is installed and Docker is configured."
echo "    Validate GPU access inside a container with:"
echo
echo "      sudo docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi"
echo
echo "    Then start your stack with GPU support:"
echo
echo "      docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d"
echo