# Docker

Container platform for building, shipping, and running applications.

## What it does

Docker allows you to package applications and their dependencies into lightweight, portable containers that can run consistently across different environments.

## Installation

Run the installation script:

```bash
./docker/install.sh
```

### What the script does

- **Detects your distribution** and installs Docker using the appropriate package manager
- **Supports multiple distros**: Ubuntu/Debian (apt), Fedora (dnf), Arch Linux (pacman)
- **Adds Docker's official GPG key** and repository for secure installation
- **Creates docker group** and adds your user to it for running Docker without sudo
- **Starts and enables** Docker service

### Manual installation

If the script fails, follow the manual installation instructions it provides for your distribution.

## Post-installation

After installation, you may need to:

1. **Log out and back in** for group changes to take effect
2. **Or run**: `newgrp docker` to apply group changes immediately

## Verification

Test your Docker installation:

```bash
docker run hello-world
```

## Key features

- **No sudo required** after proper setup
- **Multi-distribution support** with automatic detection
- **Includes Docker Compose** for multi-container applications
- **Fallback instructions** for unsupported distributions

## Dependencies

- **curl**: Required for downloading Docker installation script
- **sudo access**: Needed for system-level installation