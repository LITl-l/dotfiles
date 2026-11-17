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
          # crumb: in-repo context store-and-stub (pure-Go, builds on all platforms).
          (final: _prev: { crumb = final.callPackage ./pkgs/crumb { }; })
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

                # Home Manager installs plugins as xdg.dataFile entries under
                # site/pack/hm, not into the neovim wrapper, so the fresh
                # XDG_DATA_HOME above has none of them. Recreate the eager ones
                # at the same path the real profile uses; otherwise init.lua
                # aborts in setup_core before config.options runs, and every
                # test below then inspects an unconfigured editor (no mapleader,
                # no plugin keymaps). The opt plugins stay absent apart from the
                # one linked below -- the tests that need the rest pcall their
                # packadd.
                mkdir -p "$XDG_DATA_HOME/nvim/site/pack/hm/start"
                ln -s ${pkgs.vimPlugins.mini-nvim} \
                  "$XDG_DATA_HOME/nvim/site/pack/hm/start/mini.nvim"

                # nvim-lspconfig is the one opt plugin this sandbox does install.
                # It ships lsp/lua_ls.lua, which is where lua_ls's cmd comes from
                # -- nvim itself ships no server defaults. Leaving it out does not
                # weaken the lua_ls assertion below, it makes it unsatisfiable, so
                # absence here would only ever prove that the plugin is absent.
                mkdir -p "$XDG_DATA_HOME/nvim/site/pack/hm/opt"
                ln -s ${pkgs.vimPlugins.nvim-lspconfig} \
                  "$XDG_DATA_HOME/nvim/site/pack/hm/opt/nvim-lspconfig"

                # A Lua error raised by +cmd does not set nvim's exit code: the
                # trailing qa! quits cleanly, so a failed assertion would leave
                # this derivation green. Turn an error into :cq so each test
                # actually gates the build.
                nvim --headless -c "lua local ok, err = pcall(dofile, 'nvim/tests/external_tools.lua'); if not ok then io.stderr:write(tostring(err), '\n'); vim.cmd('cq 1') end" -c 'qa!'
                nvim --headless -c "lua local ok, err = pcall(dofile, 'nvim/tests/gc_comment.lua'); if not ok then io.stderr:write(tostring(err), '\n'); vim.cmd('cq 1') end" -c 'qa!'
                nvim --headless -c "lua local ok, err = pcall(dofile, 'nvim/tests/leader_e_minifiles.lua'); if not ok then io.stderr:write(tostring(err), '\n'); vim.cmd('cq 1') end" -c 'qa!'
                nvim --headless -c "lua local ok, err = pcall(dofile, 'nvim/tests/tutor.lua'); if not ok then io.stderr:write(tostring(err), '\n'); vim.cmd('cq 1') end" -c 'qa!'
                # setup_lsp() is deferred: a BufReadPre autocmd queues it into
                # vim.schedule so the buffer paints first. It therefore has not
                # run yet when this +cmd fires -- measured here, exists() is 0 on
                # entry and 2 one loop tick later. Pump the loop until the
                # bootstrap lands rather than racing it. A chain that never
                # completes simply exhausts the timeout and still fails below.
                nvim --headless nvim/init.lua +'lua local ok, err = pcall(function() vim.wait(10000, function() return vim.fn.exists(":LspServers") == 2 end, 50); assert(vim.fn.exists(":LspServers") == 2, "LspServers command missing"); local cfg = vim.lsp.config.lua_ls; assert(cfg and type(cfg.cmd) == "table" and #cfg.cmd > 0, "lua_ls cmd missing"); assert(vim.fn.maparg("<leader>l", "n") == "", "<leader>l maps to missing Lazy command") end); if not ok then io.stderr:write(tostring(err), "\n"); vim.cmd("cq 1") end' +'qa!'
                touch "$out"
              '';

              # Claude Code resolves a hook's `command` when the hook fires and, on a
              # path that does not exist, fails OPEN -- the tool call proceeds and
              # nothing is recorded. A hook that was never linked into ~/.claude is
              # therefore indistinguishable at runtime from one that ran and allowed
              # the call, which is how pipeline-status-guard.sh stayed registered and
              # dead. Its JSON was well-formed and schema-valid the whole time; no
              # validator asks whether the referent exists, so this does.
              #
              # Every assertion below is a fact about this repo alone, which is what
              # makes it portable. "Is this command installed on the box" -- the `xxd`
              # case from the same audit -- is a property of the runner, so it would
              # fail on CI for reasons the config cannot fix.
              claude-config-integrity =
                let
                  # The declared set is read from the EVALUATED config rather than
                  # grepped out of modules/claude-code.nix, because a grep for the
                  # declaration text goes on matching a line that has been commented
                  # out. That check would stay green at precisely the moment the link
                  # vanishes -- the inert-check failure this derivation exists to catch.
                  declaredAttrs = pkgs.writeText "claude-home-file-attrs"
                    (builtins.concatStringsSep "\n"
                      (builtins.attrNames self.homeConfigurations."nixos@wsl".config.home.file)
                      + "\n");
                in
                pkgs.runCommand "claude-config-integrity"
                  {
                    settings = ./claude/settings.json;
                    claudeDir = ./claude;
                    inherit declaredAttrs;
                  } ''
                  set -o errexit
                  set -o nounset

                  fail=0
                  note() {
                    echo "claude-config-integrity: $1"
                    fail=1
                  }

                  # `.. | objects` walks every hook group rather than the four event
                  # names known today, so a hook added under a new event is covered
                  # without editing this. split(" ")[0] keeps a command with arguments
                  # resolvable.
                  names=$(${pkgs.jq}/bin/jq -r '
                    [ .hooks // {}
                      | .. | objects
                      | select(.type? == "command")
                      | .command? // empty
                    ]
                    | map(split(" ")[0])
                    | map(select(startswith("~/.claude/")))
                    | map(ltrimstr("~/.claude/"))
                    | unique
                    | .[]
                  ' "$settings")

                  # Zero names means the selector stopped matching, not that the config
                  # is clean: the loop below would iterate nothing and exit 0.
                  if [ -z "$names" ]; then
                    note "settings.json yielded no ~/.claude/<name> hook command -- the extractor no longer matches the file, or every hook was removed"
                  fi

                  for name in $names; do
                    echo "claude-config-integrity: checking $name"

                    if [ ! -f "$claudeDir/$name" ]; then
                      note "hook command ~/.claude/$name has no file at claude/$name in this repo"
                      continue
                    fi

                    if [ ! -x "$claudeDir/$name" ]; then
                      note "claude/$name is not executable, so the hook cannot run"
                    fi

                    if ! grep -qxF ".claude/$name" "$declaredAttrs"; then
                      note "claude/$name is never linked into ~/.claude: modules/claude-code.nix declares no home.file entry for .claude/$name"
                    fi
                  done

                  if [ "$fail" -ne 0 ]; then
                    echo "claude-config-integrity: FAILED -- see the lines above"
                    exit 1
                  fi

                  echo "claude-config-integrity: every hook command resolves to a declared, executable file"
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

          # The CI job this replaces was called "Validate WezTerm Config" and
          # validated no WezTerm config: it listed eleven wezterm/*.lua files by
          # name and asserted each existed, then grepped for substrings. mux.lua,
          # sysinfo.lua and tabline-theme.lua were never on that list, so a syntax
          # error in one of them reached a terminal before it reached CI. The glob
          # is the point -- a new wezterm/*.lua is covered the moment it lands,
          # with no list to remember.
          #
          # Parsing is as far as this can go: every one of these modules opens with
          # `require("wezterm")`, which exists only inside the terminal, so loading
          # them outside it would assert nothing but the absence of wezterm.
          wezterm-lua-syntax = pkgs.runCommand "wezterm-lua-syntax"
            {
              weztermDir = ./wezterm;
              nativeBuildInputs = [ pkgs.lua5_4 ];
            } ''
            set -o errexit

            count=0
            for f in "$weztermDir"/*.lua; do
              echo "wezterm-lua-syntax: parsing $(basename "$f")"
              luac -p "$f"
              count=$((count + 1))
            done

            # Zero files means the glob stopped matching, not that the config is
            # clean -- the loop would then run no luac at all and this derivation
            # would be green on an empty assertion.
            if [ "$count" -eq 0 ]; then
              echo "wezterm-lua-syntax: matched no wezterm/*.lua"
              exit 1
            fi

            echo "wezterm-lua-syntax: $count file(s) parsed as Lua 5.4"
            touch "$out"
          '';

          # Build crumb (buildGoModule checkPhase runs `go test ./...`).
          crumb-tests = pkgs.crumb;
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

