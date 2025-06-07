# Proto

Universal toolchain manager for managing programming language versions.

## What it does

Proto is a unified toolchain manager that handles:
- **Multiple language versions** (Node.js, Python, Rust, etc.)
- **Automatic version switching** based on project files
- **Centralized tool management** with consistent CLI
- **Shim support** for seamless tool access

## Installation

Run the installation script:

```bash
./proto/install.sh
```

### Requirements

**Build essentials** are required for compiling Rust packages:

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y build-essential

# Or use the helper script
./install-build-tools.sh
```

### What the script does

- **Checks for build tools** and provides installation instructions
- **Installs Proto** from the official installer script
- **Installs Rust** via Proto for package compilation
- **Sets up environment** for current and future sessions

## Usage

### Install tools

```bash
# Install specific versions
proto install node 18.17.0
proto install python 3.11.0
proto install rust latest

# Install from project config
proto install
```

### Use tools

```bash
# Run with specific version
proto run node -- --version
proto run cargo -- build

# Use shims (after setup)
node --version
python --version
cargo --version
```

### Version management

```bash
# List available versions
proto list-remote node

# List installed versions
proto list node

# Set global default
proto global node 18.17.0

# Set local version (creates .prototools)
proto local python 3.11.0
```

## Configuration

Proto uses `.prototools` files for project-specific versions:

```toml
[tools]
node = "18.17.0"
python = "3.11.0"
rust = "1.70.0"
```

## Benefits

- **Consistent tool management** across projects
- **Automatic version switching** when entering projects
- **No need for nvm, pyenv, etc.** - one tool for all
- **Fast installation** and switching
- **Cross-platform support**

## Environment setup

Proto is configured in `zsh/env.zsh`:
- **PROTO_HOME**: Configuration directory
- **PATH**: Includes Proto shims and bin directories
- **Tool availability**: Through shims system