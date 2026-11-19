
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# Docker Setup for Arch Linux / Omarchy
# ==========================================

readonly PACKAGES=(
    docker
    docker-compose
    docker-buildx
    lazydocker
)

log() {
    printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"
}

success() {
    printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$1"
}

error() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2
    exit 1
}

# ------------------------------------------
# 1. Check distribution
# ------------------------------------------

[[ -f /etc/os-release ]] || error "Cannot identify distribution."

source /etc/os-release

if [[ "${ID:-}" != "arch" && " ${ID_LIKE:-} " != *" arch "* ]]; then
    error "Arch Linux or an Arch-based distribution is required."
fi

command -v pacman >/dev/null 2>&1 || error "pacman not found."
command -v systemctl >/dev/null 2>&1 || error "systemctl not found."

# ------------------------------------------
# 2. Check privileges and user
# ------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    TARGET_USER="${SUDO_USER:-root}"
else
    TARGET_USER="$USER"
fi

[[ "$TARGET_USER" != "root" ]] || error "Run as a regular user, not root."

id "$TARGET_USER" >/dev/null 2>&1 || error "User does not exist."

if [[ "$EUID" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || error "sudo is required."
    sudo -v
fi

# Run privileged commands through one helper.
run_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ------------------------------------------
# 3. Install packages
# ------------------------------------------

log "Installing Docker and related packages..."

run_root pacman -S --needed --noconfirm "${PACKAGES[@]}"

# ------------------------------------------
# 4. Configure Docker group
# ------------------------------------------

log "Configuring Docker group..."

if ! getent group docker >/dev/null 2>&1; then
    run_root groupadd docker
fi

if ! id -nG "$TARGET_USER" | grep -qw docker; then
    run_root usermod -aG docker "$TARGET_USER"
    GROUP_CHANGED=true
else
    GROUP_CHANGED=false
fi

# ------------------------------------------
# 5. Enable Docker
# ------------------------------------------

log "Enabling Docker service..."

run_root systemctl enable --now docker.service

systemctl is-active --quiet docker.service \
    || error "Docker service failed to start."

# ------------------------------------------
# 6. Verify installation
# ------------------------------------------

log "Verifying installed components..."

docker --version || error "Docker CLI verification failed."
docker compose version || error "Docker Compose verification failed."
docker buildx version || error "Docker Buildx verification failed."
lazydocker --version || error "Lazydocker verification failed."

# ------------------------------------------
# 7. Finish
# ------------------------------------------

echo
success "Docker environment installed successfully!"

echo
echo "Installed:"
echo "  - Docker Engine"
echo "  - Docker CLI"
echo "  - Docker Compose"
echo "  - Docker Buildx"
echo "  - Lazydocker"

echo
echo "Docker service: $(systemctl is-active docker.service)"

if [[ "$GROUP_CHANGED" == true ]]; then
    echo
    echo "IMPORTANT: Log out and log back in to activate"
    echo "your Docker group membership."
fi

echo
echo "Quick tests:"
echo "  docker run hello-world"
echo "  docker compose version"
echo "  lazydocker"

echo
success "Installation complete!"

