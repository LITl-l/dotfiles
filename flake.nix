{
  description = "Cross-platform dotfiles with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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
              programs.wezterm.enable = false; # Use Windows WezTerm
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
              programs.wezterm.enable = false; # Use Windows WezTerm
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

      # Development shell for testing
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            name = "dotfiles-dev";
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil # Nix LSP
              home-manager
            ];
          };
        });

      # Formatting
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);
    };
}
