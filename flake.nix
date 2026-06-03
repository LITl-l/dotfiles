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

    # headroom context-compression MCP server (native binary via Cachix)
    headroom = {
      url = "github:LITl-l/headroom-overlay";
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
        ] ++ nixpkgs.lib.optionals (system == "x86_64-linux") [
          # headroom-overlay only publishes x86_64-linux; gate it so the
          # darwin/aarch64 configs (and `nix flake check`) still evaluate.
          inputs.headroom.overlays.default
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
          linuxChecks =
            if system == "x86_64-linux" then {
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
        in
        {
          pi-assistant-insight-tests = pkgs.runCommand "pi-assistant-insight-tests"
            {
              src = self;
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            cp -R "$src" source
            chmod -R u+w source
            cd source
            node --test pi/assistant-insight/core.test.ts

            export PI_NODE_MODULES="${pkgs.pi-coding-agent}/lib/node_modules"
            export PI_ASSISTANT_INSIGHT_CORE="$PWD/pi/assistant-insight/core.ts"
            node --input-type=module <<'NODE'
            import assert from "node:assert/strict";
            import { readFileSync, writeFileSync } from "node:fs";
            import { tmpdir } from "node:os";
            import { join } from "node:path";

            const tmpIndex = join(tmpdir(), "assistant-insight-index.ts");
            const source = readFileSync("pi/assistant-insight/index.ts", "utf8")
              .replaceAll("@PI_NODE_MODULES@", process.env.PI_NODE_MODULES)
              .replaceAll("@PI_ASSISTANT_INSIGHT_CORE@", process.env.PI_ASSISTANT_INSIGHT_CORE);

            assert.equal(source.includes("@PI_"), false);
            writeFileSync(tmpIndex, source);

            const themeModule = await import(
              "file://" + process.env.PI_NODE_MODULES + "/@earendil-works/pi-coding-agent/dist/modes/interactive/theme/theme.js"
            );
            themeModule.initTheme("dark", false);

            const extension = await import("file://" + tmpIndex);
            extension.default();

            const { AssistantMessageComponent } = await import(
              "file://" + process.env.PI_NODE_MODULES + "/@earendil-works/pi-coding-agent/dist/modes/interactive/components/assistant-message.js"
            );
            const component = new AssistantMessageComponent({
              role: "assistant",
              content: [{ type: "text", text: "Useful insight.\n\nRemaining response." }],
              stopReason: "stop",
            });
            const rendered = component.render(100).join("\n");

            assert.equal(component.contentContainer.children.length, 4);
            assert.equal(component.contentContainer.children[0].constructor.name, "Spacer");
            assert.equal(component.contentContainer.children[1].constructor.name, "Box");
            assert.equal(component.contentContainer.children[2].constructor.name, "Spacer");
            assert.match(rendered, /Insight/);
            assert.match(rendered, /Useful insight\./);
            assert.match(rendered, /Remaining response\./);
            assert.equal(rendered.match(/Useful insight\./g)?.length, 1);
            NODE

            touch "$out"
          '';

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

          pi-auto-model-router-tests = pkgs.runCommand "pi-auto-model-router-tests"
            {
              src = self;
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            cp -R "$src" source
            chmod -R u+w source
            cd source
            node --test pi/auto-model-router/core.test.ts pi/auto-model-router/index.test.ts
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

