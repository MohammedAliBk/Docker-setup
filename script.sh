
#!/usr/bin/env bash

set -Eeuo pipefail

# Check distribution
if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot identify Linux distribution."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "arch" && " ${ID_LIKE:-} " != *" arch "* ]]; then
    echo "ERROR: This installer supports Arch-based distributions only."
    exit 1
fi

# Check package manager
if ! command -v pacman &>/dev/null; then
    echo "ERROR: pacman is required."
    exit 1
fi

# Resolve the actual user, including sudo execution
TARGET_USER="${SUDO_USER:-$(whoami)}"

if [[ "$TARGET_USER" == "root" ]]; then
    echo "ERROR: Run this script as a regular user with sudo privileges."
    exit 1
fi

if ! id "$TARGET_USER" &>/dev/null; then
    echo "ERROR: User $TARGET_USER does not exist."
    exit 1
fi

echo "=================================="
echo " Docker + Compose + Lazydocker"
echo "=================================="
echo "Distribution: ${PRETTY_NAME:-Arch-based}"
echo "User: $TARGET_USER"
echo

# Require sudo
sudo -v

# Update system and install packages
echo "[1/5] Updating system..."
sudo pacman -Syu --noconfirm

echo "[2/5] Installing Docker and tools..."
sudo pacman -S --needed --noconfirm \
    docker \
    docker-compose \
    docker-buildx \
    lazydocker

# Add user to Docker group
echo "[3/5] Configuring Docker group..."
if ! id -nG "$TARGET_USER" | grep -qw docker; then
    sudo usermod -aG docker "$TARGET_USER"
    echo "Added $TARGET_USER to docker group."
else
    echo "$TARGET_USER is already in docker group."
fi

# Enable Docker
echo "[4/5] Enabling Docker service..."
sudo systemctl enable --now docker.service

# Verify installation
echo "[5/5] Verifying installation..."

docker --version
docker compose version
docker buildx version
lazydocker --version

echo
echo "=================================="
echo " Installation completed!"
echo "=================================="
echo
echo "Docker service:"
systemctl is-active docker

echo
echo "IMPORTANT:"
echo "Log out and log back in to activate"
echo "your Docker group membership."
echo
echo "Then test with:"
echo "  docker run hello-world"
echo "  docker compose version"
echo "  lazydocker"
echo
echo "Installation finished."

