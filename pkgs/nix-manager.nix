{ lib, writeShellScriptBin, jq, nix, home-manager }:

writeShellScriptBin "nix-manager" ''
  set -euo pipefail

  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  # Default values
  DOTFILES_PATH="''${HOME}/.config/dotfiles"
  ACTION=""
  FLAKE_UPDATE=false

  # Function to print colored messages
  print_info() {
      echo -e "''${BLUE}ℹ''${NC} $1"
  }

  print_success() {
      echo -e "''${GREEN}✓''${NC} $1"
  }

  print_error() {
      echo -e "''${RED}✗''${NC} $1"
  }

  print_warning() {
      echo -e "''${YELLOW}⚠''${NC} $1"
  }

  # Function to detect the current user and system
  detect_configuration() {
      local username=$(whoami)
      local system=$(uname -s)

      # Determine configuration name based on user and system
      if [[ "$system" == "Linux" ]]; then
          # Check if running in WSL
          if grep -qi microsoft /proc/version 2>/dev/null; then
              echo "''${username}@wsl"
          else
              echo "''${username}@linux"
          fi
      elif [[ "$system" == "Darwin" ]]; then
          echo "''${username}@darwin"
      else
          print_error "Unsupported system: $system"
          exit 1
      fi
  }

  # Function to show usage
  usage() {
      cat << EOF
  Usage: nix-manager [COMMAND] [OPTIONS]

  A unified script to manage Nix home-manager configurations.

  COMMANDS:
      rebuild, switch     Rebuild and switch to the new configuration
      update              Update flake inputs and rebuild
      clean               Run garbage collection
      list                List available configurations
      help                Show this help message

  OPTIONS:
      -p, --path PATH     Path to dotfiles (default: ~/.config/dotfiles)
      -c, --config NAME   Specify configuration name (auto-detected if not provided)
      -h, --help          Show this help message

  EXAMPLES:
      nix-manager rebuild                    # Auto-detect config and rebuild
      nix-manager update                     # Update flake and rebuild
      nix-manager rebuild -c user@wsl        # Use specific configuration
      nix-manager clean                      # Clean old generations

  CONFIGURATIONS:
      The script auto-detects your configuration based on username and system:
      - user@linux   : Generic Linux
      - user@wsl     : WSL2 (non-NixOS)
      - nixos@wsl    : NixOS on WSL2
      - user@darwin  : macOS

  EOF
  }

  # Function to list available configurations
  list_configurations() {
      print_info "Available home-manager configurations in flake:"
      echo ""

      if [[ -f "''${DOTFILES_PATH}/flake.nix" ]]; then
          ${nix}/bin/nix eval "''${DOTFILES_PATH}#homeConfigurations" --apply builtins.attrNames --json 2>/dev/null | \
              ${jq}/bin/jq -r '.[]' | \
              while read -r config; do
                  echo "  • ''${config}"
              done
      else
          print_error "flake.nix not found at ''${DOTFILES_PATH}"
          exit 1
      fi
  }

  # Function to update flake
  update_flake() {
      print_info "Updating flake inputs..."

      if ! ${nix}/bin/nix flake update "''${DOTFILES_PATH}"; then
          print_error "Failed to update flake"
          exit 1
      fi

      print_success "Flake updated successfully"
  }

  # Function to rebuild home-manager configuration
  rebuild_config() {
      local config_name=$1

      print_info "Rebuilding home-manager configuration: ''${config_name}"
      print_info "Using flake path: ''${DOTFILES_PATH}"

      # Check if flake.nix exists
      if [[ ! -f "''${DOTFILES_PATH}/flake.nix" ]]; then
          print_error "flake.nix not found at ''${DOTFILES_PATH}"
          exit 1
      fi

      # Check if configuration exists in flake
      if ! ${nix}/bin/nix eval "''${DOTFILES_PATH}#homeConfigurations.\"''${config_name}\"" --raw 2>/dev/null >/dev/null; then
          print_error "Configuration ''${config_name} not found in flake"
          print_warning "Run 'nix-manager list' to see available configurations"
          exit 1
      fi

      # Run home-manager switch
      print_info "Running home-manager switch..."
      if ${home-manager}/bin/home-manager switch --flake "''${DOTFILES_PATH}#''${config_name}"; then
          print_success "Home-manager configuration applied successfully!"
      else
          print_error "Failed to apply home-manager configuration"
          exit 1
      fi
  }

  # Function to run garbage collection
  clean_system() {
      print_info "Running Nix garbage collection..."

      if ${nix}/bin/nix-collect-garbage -d; then
          print_success "Garbage collection completed"
      else
          print_error "Garbage collection failed"
          exit 1
      fi
  }

  # Parse command line arguments
  CONFIG_NAME=""

  if [[ $# -eq 0 ]]; then
      usage
      exit 0
  fi

  # Parse command
  case "$1" in
      rebuild|switch)
          ACTION="rebuild"
          shift
          ;;
      update)
          ACTION="update"
          FLAKE_UPDATE=true
          shift
          ;;
      clean)
          ACTION="clean"
          shift
          ;;
      list)
          ACTION="list"
          shift
          ;;
      help|-h|--help)
          usage
          exit 0
          ;;
      *)
          print_error "Unknown command: $1"
          echo ""
          usage
          exit 1
          ;;
  esac

  # Parse options
  while [[ $# -gt 0 ]]; do
      case "$1" in
          -p|--path)
              DOTFILES_PATH="$2"
              shift 2
              ;;
          -c|--config)
              CONFIG_NAME="$2"
              shift 2
              ;;
          -h|--help)
              usage
              exit 0
              ;;
          *)
              print_error "Unknown option: $1"
              echo ""
              usage
              exit 1
              ;;
      esac
  done

  # Execute action
  case "$ACTION" in
      list)
          list_configurations
          ;;
      clean)
          clean_system
          ;;
      rebuild|update)
          # Auto-detect configuration if not specified
          if [[ -z "$CONFIG_NAME" ]]; then
              CONFIG_NAME=$(detect_configuration)
              print_info "Auto-detected configuration: ''${CONFIG_NAME}"
          fi

          # Update flake if requested
          if [[ "$FLAKE_UPDATE" == "true" ]]; then
              update_flake
          fi

          # Rebuild configuration
          rebuild_config "$CONFIG_NAME"
          ;;
  esac
''
