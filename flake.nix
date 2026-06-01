{
  description = "Cross-platform dotfiles with Home Manager";

  inputs = {
    # nixpkgs-unstable (not nixos-unstable): faster-moving Hydra channel that
    # stays version-aligned with home-manager's master branch. nixos-unstable
    # lags around release time and triggers HM's version-mismatch warning.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fish plugins
    fish-plugin-z = {
      url = "github:jethrokuan/z";
      flake = false;
    };

    fish-plugin-fzf = {
      url = "github:PatrickF1/fzf.fish";
      flake = false;
    };

    # Claude Code (native binary with Cachix)
    claude-code = {
      url = "github:ryoppippi/claude-code-overlay";
    };

    # Pi coding agent (native binary with Cachix)
    pi = {
      url = "github:lukasl-dev/pi.nix";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Systems to support
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Helper to generate an attr set per system
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Nixpkgs instance for each system
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.claude-code.overlays.default
          inputs.pi.overlays.default
        ];
      });
    in
    {
      # Home Manager configurations
      homeConfigurations = {
        # Linux configuration
        "user@linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgsFor.x86_64-linux;
          modules = [
            ./home.nix
            {
              home = {
                username = "user";
                homeDirectory = "/home/user";
                stateVersion = "24.05";
              };
              targets.genericLinux.enable = true;
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        # WSL2 configuration
        "user@wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgsFor.x86_64-linux;
          modules = [
            ./home.nix
            {
              home = {
                username = "user";
                homeDirectory = "/home/user";
                stateVersion = "24.05";
              };
              targets.genericLinux.enable = true;
              # WSL-specific settings
              dotfiles.hyprland.enable = true;
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        # NixOS on WSL2 configuration
        "nixos@wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgsFor.x86_64-linux;
          modules = [
            ./home.nix
            {
              home = {
                username = "nixos";
                homeDirectory = "/home/nixos";
                stateVersion = "24.05";
              };
              targets.genericLinux.enable = true;
              # WSL-specific settings
              dotfiles.hyprland.enable = true;
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        # macOS configuration
        "user@darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgsFor.aarch64-darwin;
          modules = [
            ./home.nix
            {
              home = {
                username = "user";
                homeDirectory = "/Users/user";
                stateVersion = "24.05";
              };
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Expose activation packages for nix build
      packages = {
        x86_64-linux = {
          "homeConfigurations/user@linux" = self.homeConfigurations."user@linux".activationPackage;
          "homeConfigurations/user@wsl" = self.homeConfigurations."user@wsl".activationPackage;
          "homeConfigurations/nixos@wsl" = self.homeConfigurations."nixos@wsl".activationPackage;
        };
        aarch64-linux = { };
        x86_64-darwin = { };
        aarch64-darwin = {
          "homeConfigurations/user@darwin" = self.homeConfigurations."user@darwin".activationPackage;
        };
      };

      # Test checks
      checks = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          linuxChecks = if system == "x86_64-linux" then {
            nvim-config-tests = pkgs.runCommand "nvim-config-tests"
              {
                src = self;
                nativeBuildInputs = [ self.homeConfigurations."nixos@wsl".config.programs.neovim.finalPackage ];
              } ''
              cp -R "$src" source
              chmod -R u+w source
              cd source
              export XDG_CONFIG_HOME="$PWD"
              export XDG_DATA_HOME="$TMPDIR/data"
              export XDG_STATE_HOME="$TMPDIR/state"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              nvim --headless +'luafile nvim/tests/leader_e_minifiles.lua' +'qa!'
              nvim --headless nvim/init.lua +'lua assert(vim.fn.exists(":LspServers") == 2, "LspServers command missing"); local cfg = vim.lsp.config.lua_ls; assert(cfg and type(cfg.cmd) == "table" and #cfg.cmd > 0, "lua_ls cmd missing"); assert(vim.fn.maparg("<leader>l", "n") == "", "<leader>l maps to missing Lazy command")' +'qa!'
              touch "$out"
            '';
          } else { };
        in {
          pi-goal-tests = pkgs.runCommand "pi-goal-tests"
            {
              src = self;
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            cp -R "$src" source
            chmod -R u+w source
            cd source
            node --test pi/goal/core.test.ts pi/goal/index.test.ts
            touch "$out"
          '';

          pi-subagents-tests = pkgs.runCommand "pi-subagents-tests"
            {
              src = self;
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            cp -R "$src" source
            chmod -R u+w source
            cd source
            node --test pi/subagents/core.test.ts
            touch "$out"
          '';
        } // linuxChecks);

      # Development shell for testing
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            name = "dotfiles-dev";
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil # Nix LSP
              pkgs.home-manager
            ];
          };
        });

      # Formatting
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);
    };
}

