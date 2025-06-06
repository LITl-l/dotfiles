#!/usr/bin/env bash

# Docker setup script

set -euo pipefail

echo "Setting up Docker..."

# Check if docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker not found. Please install Docker first:"
    echo "https://docs.docker.com/engine/install/"
    exit 1
fi

# Create docker group if it doesn't exist
if ! getent group docker >/dev/null 2>&1; then
    echo "Creating docker group..."
    sudo groupadd docker
fi

# Add current user to docker group
if ! groups "$USER" | grep -q docker; then
    echo "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    echo "You need to log out and back in for docker group changes to take effect"
else
    echo "User $USER already in docker group"
fi

echo "Docker setup complete!"