#!/usr/bin/env bash

# Docker setup script

set -euo pipefail

echo "Setting up Docker..."

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker not found. Installation requires sudo access."
    
    # Check if sudo is available without password
    if ! sudo -n true 2>/dev/null; then
        echo ""
        echo "Docker installation requires sudo access. Please install Docker manually:"
        echo ""
        
        if command -v apt-get >/dev/null 2>&1; then
            echo "For Ubuntu/Debian:"
            echo "  # Add Docker's official GPG key:"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install ca-certificates curl"
            echo "  sudo install -m 0755 -d /etc/apt/keyrings"
            echo "  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
            echo "  sudo chmod a+r /etc/apt/keyrings/docker.asc"
            echo ""
            echo "  # Add the repository to Apt sources:"
            echo "  echo \\"
            echo "    \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\"
            echo "    \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | \\"
            echo "    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
            echo ""
            echo "  # Install Docker:"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
        elif command -v dnf >/dev/null 2>&1; then
            echo "For Fedora:"
            echo "  sudo dnf -y install dnf-plugins-core"
            echo "  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
            echo "  sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
        elif command -v pacman >/dev/null 2>&1; then
            echo "For Arch Linux:"
            echo "  sudo pacman -S docker docker-compose"
        fi
        
        echo ""
        echo "  # Start Docker:"
        echo "  sudo systemctl start docker"
        echo "  sudo systemctl enable docker"
        echo ""
        echo "Then re-run this script to complete the setup."
        exit 1
    fi
    
    echo "Installing Docker..."
    
    # Detect the distribution and install accordingly
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing Docker on Debian/Ubuntu..."
        
        # Add Docker's official GPG key
        echo "Adding Docker GPG key..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add the repository to Apt sources
        echo "Adding Docker repository..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker packages
        echo "Installing Docker packages..."
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing Docker on Fedora..."
        
        # Remove old versions
        sudo dnf -y remove docker \
                     docker-client \
                     docker-client-latest \
                     docker-common \
                     docker-latest \
                     docker-latest-logrotate \
                     docker-logrotate \
                     docker-selinux \
                     docker-engine-selinux \
                     docker-engine
        
        # Install Docker
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing Docker on Arch Linux..."
        sudo pacman -S --noconfirm docker docker-compose
        
    else
        echo "Error: Unsupported distribution for automatic Docker installation"
        echo "Please install Docker manually:"
        echo "https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Start and enable Docker service
    echo "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Verify Docker installation
    if command -v docker >/dev/null 2>&1; then
        echo "Docker installed successfully"
    else
        echo "Error: Docker installation failed"
        exit 1
    fi
else
    echo "Docker already installed"
fi

# Create docker group if it doesn't exist
if ! getent group docker >/dev/null 2>&1; then
    echo "Creating docker group..."
    sudo groupadd docker
fi

# Add current user to docker group
if ! groups "$USER" | grep -q docker; then
    echo "Adding $USER to docker group..."
    if sudo -n true 2>/dev/null; then
        sudo usermod -aG docker "$USER"
        echo ""
        echo "IMPORTANT: You need to log out and back in for docker group changes to take effect."
        echo "Alternatively, you can run: newgrp docker"
    else
        echo ""
        echo "To run Docker without sudo, add yourself to the docker group:"
        echo "  sudo usermod -aG docker $USER"
        echo "Then log out and back in, or run: newgrp docker"
    fi
else
    echo "User $USER already in docker group"
fi

echo ""
echo "Docker setup complete!"
echo ""
echo "To verify Docker installation:"
echo "  docker run hello-world"