# Docker

> ℹ️ **STANDALONE TOOL**: Docker is intentionally not managed by the Nix configuration as it's a system-level container platform that's typically installed via distribution package managers.
>
> **Note**: This installation script remains valid and useful. Docker is not included in the main Nix configuration because:
> - Docker requires system-level daemon configuration
> - Most users prefer distribution-specific Docker packages
> - Docker Desktop (on macOS/Windows) is often preferred
>
> Use this script if you need Docker installed on Linux. For NixOS, use the system-level NixOS Docker configuration instead.

---

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