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

          # ~2,700 lines of bash run real work here -- the fleet control plane, two
          # measurement tools whose output is committed, and nine hook scripts that
          # gate every tool call -- and none of it was analysed. The bug this found on
          # its first run was in claude-corpus: an unquoted $(grep ...) split a corpus
          # path on spaces, and the `|| printf '[]'` beside it turned the resulting
          # failure into `agents_used: []`, a wrong number reported as a real one.
          #
          # Membership is decided by SHEBANG, not by filename. scripts/fleet,
          # scripts/claude-corpus and scripts/rework-rate carry no .sh, so a *.sh glob
          # would have covered none of them, and a hand-listed set is the defect this
          # repo removed from seven other places -- it goes stale the moment someone
          # adds a script. The shebang is the same question the kernel answers when it
          # picks an interpreter, so it is the right one to ask here. *.sh is unioned
          # in anyway, so a fragment that is shell but carries no shebang still lands.
          shellcheck = pkgs.runCommand "shellcheck"
            {
              src = self;
              nativeBuildInputs = [ pkgs.shellcheck ];
            } ''
            set -o errexit

            cp -R "$src" source
            chmod -R u+w source
            cd source

            : > "$TMPDIR/scripts.list"
            find . -type f | sort | while IFS= read -r f; do
              case "$f" in *.sh) echo "$f" >> "$TMPDIR/scripts.list"; continue ;; esac
              line=$(head -n 1 "$f" 2>/dev/null || true)
              case "$line" in '#!'*) ;; *) continue ;; esac
              # Resolve `#!/usr/bin/env bash` to `bash` as well as a direct path, so
              # the two spellings in this tree are not treated as different languages.
              # shellcheck disable=SC2086
              set -- ''${line#\#!}
              interp=$(basename "''${1:-}")
              if [ "$interp" = env ]; then shift; interp=$(basename "''${1:-}"); fi
              case "$interp" in
                bash|sh|dash|ksh) echo "$f" >> "$TMPDIR/scripts.list" ;;
              esac
            done

            count=0
            while IFS= read -r f; do
              echo "shellcheck: checking ''${f#./}"
              shellcheck --format=gcc "$f"
              count=$((count + 1))
            done < <(sort -u "$TMPDIR/scripts.list")

            # Zero files means the shebang scan stopped matching, not that the tree is
            # clean -- the loop would then run no shellcheck at all and this derivation
            # would be green on an empty assertion.
            if [ "$count" -eq 0 ]; then
              echo "shellcheck: matched no shell scripts"
              exit 1
            fi

            echo "shellcheck: $count script(s) analysed"
            touch "$out"
          '';

          # WHY SHELLCHECK IS NOT ENOUGH FOR scripts/automerge-eligible. shellcheck
          # proves the script is valid bash. It cannot prove the policy is right, and
          # this script decides what merges without a human reading it.
          #
          # THE DEFECT THAT MADE THIS NECESSARY, so nobody deletes it as redundant: the
          # leak scan matched `worktree` as a SUBSTRING, and `tool.EnterWorktree.calls`
          # is an ordinary metric row that contains it. One refused added line refuses
          # the whole pull request, and claude-corpus emits roughly eighty `tool.*` rows
          # per run, so a single use of that tool anywhere in the measurement window
          # killed auto-merge for every ledger pull request. It shipped that way. Seven
          # hand-written fixtures all passed, because every one of them was synthetic and
          # agreed with the author's idea of what a ledger row looks like.
          #
          # SO THE ELIGIBLE CASE IS BUILT FROM THE COMMITTED LEDGER, NOT FROM A SAMPLE
          # PASTED HERE. It re-appends every real data row to the real file, which
          # exercises every metric name claude-corpus has ever emitted as an ADDED line,
          # and then asserts the script reported scanning exactly that many. A pasted
          # sample would keep passing while the real file moved underneath it; this goes
          # red the day a new metric name trips the scan, and names the row.
          automerge-selftest = pkgs.runCommand "automerge-selftest"
            {
              src = self;
              nativeBuildInputs = [ pkgs.bash pkgs.git ];
            } ''
            set -o errexit

            export HOME="$TMPDIR"
            cp -R "$src" source
            chmod -R u+w source
            cd source

            ledger=docs/claude-corpus-ledger.tsv
            # Run through `bash` rather than the shebang: the build sandbox has no
            # /usr/bin/env, so `#!/usr/bin/env bash` cannot resolve here. That is a
            # property of this sandbox, not of the script -- GitHub's runners have it,
            # and the workflow invokes ./scripts/automerge-eligible directly.
            bin=$PWD/scripts/automerge-eligible

            # Each case is an a/ tree and a b/ tree holding the real ledger, diffed by
            # git rather than written out here, so the fixture has the same shape as what
            # `gh pr diff` hands the script in CI. The empty prefixes let the literal a/
            # and b/ directories supply the a//b/ that git normally prepends.
            newcase() {
              mkdir -p "$TMPDIR/$1/a/docs" "$TMPDIR/$1/b/docs"
              cp "$ledger" "$TMPDIR/$1/a/$ledger"
              cp "$ledger" "$TMPDIR/$1/b/$ledger"
              echo "$ledger" > "$TMPDIR/$1/files.txt"
            }

            gendiff() {
              git -C "$TMPDIR/$1" diff --no-index --src-prefix= --dst-prefix= a b \
                > "$TMPDIR/$1/diff.txt" || true
            }

            count=0
            expect() {
              name=$1; want=$2; author=$3; what=$4
              rc=0
              bash "$bin" --author "$author" --files "$TMPDIR/$name/files.txt" \
                --diff "$TMPDIR/$name/diff.txt" > "$TMPDIR/$name/verdict" || rc=$?
              if [ "$rc" -ne "$want" ]; then
                echo "automerge-selftest: FAIL $name ($what): wanted exit $want, got $rc"
                cat "$TMPDIR/$name/verdict"
                exit 1
              fi
              echo "automerge-selftest: ok $name -> exit $rc ($what)"
              count=$((count + 1))
            }

            rows=$(grep -cEv '^#|^run_utc' "$ledger")
            if [ "$rows" -eq 0 ]; then
              echo "automerge-selftest: the ledger has no data rows to build a case from"
              exit 1
            fi

            # (1) The case the substring bug broke. Every committed row, re-appended.
            newcase real-append
            grep -Ev '^#|^run_utc' "$ledger" >> "$TMPDIR/real-append/b/$ledger"
            gendiff real-append
            expect real-append 0 LITl-l "every committed ledger row is eligible as an append"

            # Exit 0 alone would also be reported by a script that scanned nothing, so
            # make it say how many added lines it actually looked at.
            if ! grep -q "^eligible: $rows line(s)" "$TMPDIR/real-append/verdict"; then
              echo "automerge-selftest: FAIL real-append did not scan all $rows row(s)"
              cat "$TMPDIR/real-append/verdict"
              exit 1
            fi
            echo "automerge-selftest: ok real-append scanned all $rows row(s)"
            count=$((count + 1))

            # (2) Widening the boundaries must not have widened the hole: a leak spelled
            # as a whole token still refuses.
            newcase leak-employer
            printf '2026-11-18T04:00:00Z\t2026-10-17\t2026-11-18\t540\t280\tproject.Digital.Emc.sessions\t7\n' \
              >> "$TMPDIR/leak-employer/b/$ledger"
            gendiff leak-employer
            expect leak-employer 1 LITl-l "an employer identifier as a whole token is refused"

            newcase leak-wkspace
            printf '2026-11-18T04:00:00Z\t2026-10-17\t2026-11-18\t540\t280\tcorpus.wkspace.records\t7\n' \
              >> "$TMPDIR/leak-wkspace/b/$ledger"
            gendiff leak-wkspace
            expect leak-wkspace 1 LITl-l "a workspace identifier as a whole token is refused"

            # (3) A path outside the allowlist, which is what keeps the rule from
            # widening itself: `.github/**` and `scripts/**` are not on it either.
            mkdir -p "$TMPDIR/foreign-path"
            cp "$TMPDIR/real-append/diff.txt" "$TMPDIR/foreign-path/diff.txt"
            printf '%s\nclaude/settings.json\n' "$ledger" > "$TMPDIR/foreign-path/files.txt"
            expect foreign-path 1 LITl-l "a changed path outside the allowlist is refused"

            # (4) Append-only, verified rather than assumed.
            newcase removal
            sed -i '5d' "$TMPDIR/removal/b/$ledger"
            gendiff removal
            expect removal 1 LITl-l "removing an existing ledger line is refused"

            # (5) This repository is public; a fork can open a pull request.
            mkdir -p "$TMPDIR/foreign-author"
            cp "$TMPDIR/real-append/diff.txt" "$TMPDIR/foreign-author/diff.txt"
            cp "$TMPDIR/real-append/files.txt" "$TMPDIR/foreign-author/files.txt"
            expect foreign-author 1 not-the-owner "an author who is not the owner is refused"

            # Zero cases means the case list stopped running, not that the policy is
            # right -- the same empty assertion this check exists to prevent.
            if [ "$count" -eq 0 ]; then
              echo "automerge-selftest: no cases ran"
              exit 1
            fi

            echo "automerge-selftest: $count case(s) asserted over $rows real ledger row(s)"
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

