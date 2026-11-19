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

          # WHY A SELF-TEST WITH A FAKE DAEMON. The guard's whole job is to believe the
          # session inventory and act on it, so what has to be tested is what it does
          # when the inventory says each of the things it can say: a live session here,
          # a finished one, one in another directory, an interactive one, a state no
          # version has used yet, a daemon that will not answer. None of that is
          # reachable by dispatching real workers -- you get the happy path and nothing
          # else -- and the paths you cannot exercise are the ones that ship broken. So
          # `claude` is replaced on PATH by a fake whose answers the cases control.
          #
          # EVERY CASE WAS WATCHED FAILING. Each assertion was run against a copy of the
          # script with the check it covers removed, and each went red before the check
          # was restored. A test never seen failing proves nothing.
          #
          # THE CONTENTION CASE NEEDS A STARTING GATE, which is why it takes one. A
          # dispatch takes seconds and the session appears only at the end of it, so two
          # spawns that merely take turns asking both see an empty directory and both
          # dispatch -- the original incident. Started in a plain loop the two contenders
          # never overlap and the case passes with the locking deleted; a flock barrier
          # releases them in the same instant, and then the unlocked variant dispatches
          # twice.
          fleet-spawn-guard-selftest = pkgs.runCommand "fleet-spawn-guard-selftest"
            {
              src = self;
              nativeBuildInputs = [ pkgs.bash pkgs.jq pkgs.util-linux ];
            } ''
            export HOME="$TMPDIR"
            cp -R "$src" source
            chmod -R u+w source
            cd source

            set -o errexit
            set -o nounset
            set -o errtrace
            # Stated rather than inherited. The nix builder turns pipefail on and an interactive
            # shell leaves it off, so a harness that does not say which it wants runs two different
            # programs in the two places -- and the one that only runs in CI is the one nobody
            # watches fail.
            set -o pipefail

            # Without this an unexpected failure anywhere below leaves a bare exit 1 and no clue --
            # a check that stopped checking and said nothing.
            trap 'echo "guard-selftest: ABORTED on line $LINENO running: $BASH_COMMAND" >&2' ERR

            SRC_GUARD=''${GUARD_BIN:-$PWD/scripts/fleet-spawn-guard}
            SRC_FLEET=''${FLEET_BIN:-$PWD/scripts/fleet}

            work=$(mktemp -d)
            mkdir -p "$work/bin"
            export FAKE_INV="$work/inventory.json"

            # A FAKE DAEMON. The guard's whole job is to believe the authority and act on what it
            # says, so the test has to be able to make the authority say things -- a live session
            # here, a finished one there, an unreachable daemon, a dispatch that registers nothing.
            # None of that is reachable by dispatching real workers, and a test that can only
            # observe the happy path is the one that lets the other paths ship.
            # The shebang is written out rather than spelled `#!/usr/bin/env bash`, for the same
            # reason as the two copies below: the build sandbox has no /usr/bin/env, and a fake
            # daemon that cannot start looks exactly like a daemon that will not answer.
            BASH_BIN=$(command -v bash)
            {
              printf '#!%s\n' "$BASH_BIN"
              cat <<'FAKE'
            set -o nounset
            INV=''${FAKE_INV:?}
            if [ "''${1:-}" = agents ]; then
              if [ -n "''${FAKE_AUTHORITY_BROKEN:-}" ]; then echo "could not reach the daemon" >&2; exit 1; fi
              if [ -n "''${FAKE_AUTHORITY_GARBAGE:-}" ]; then echo "<html>gateway timeout</html>"; exit 0; fi
              # Accepts the question and never answers -- the shape that parks a holder forever.
              if [ -n "''${FAKE_AUTHORITY_HANG:-}" ]; then sleep 300; exit 0; fi
              # A well-formed array whose rows use different field names.
              if [ -n "''${FAKE_AUTHORITY_RENAMED:-}" ]; then
                echo '[{"session_kind":"background","directory":"/somewhere","run_state":"working"}]'
                exit 0
              fi
              cat "$INV"
              exit 0
            fi
            # Anything else is a dispatch.
            if [ -n "''${FAKE_DISPATCH_FAIL:-}" ]; then echo "dispatch exploded" >&2; exit 7; fi
            if [ -n "''${FAKE_DISPATCH_LINGER:-}" ]; then ( exec sleep 30 ) > /dev/null 2>&1 & fi
            sleep "''${FAKE_DISPATCH_SECONDS:-1}"
            if [ -n "''${FAKE_DISPATCH_SILENT:-}" ]; then echo "backgrounded (but registering nothing)"; exit 0; fi
            id=$(tr -dc a-f0-9 < /dev/urandom 2>/dev/null | head -c 8 || echo deadbeef)
            tmp=$(mktemp)
            jq --arg id "$id" --arg cwd "$PWD" --arg n "''${FAKE_NAME:-worker}" \
              --argjson pid "''${FAKE_LIVE_PID:-1}" \
              '. + [{id:$id, sessionId:($id+"-0000-0000"), cwd:$cwd, kind:"background", name:$n, state:"working", pid:$pid}]' \
              "$INV" > "$tmp" && mv "$tmp" "$INV"
            echo "backgrounded · $id · ''${FAKE_NAME:-worker}"
            exit 0
            FAKE
            } > "$work/bin/claude"
            chmod +x "$work/bin/claude"

            # Copying both scripts side by side with a resolvable shebang also keeps fleet's "look
            # beside myself first" lookup of the guard exactly as it is in a checkout.
            { printf '#!%s\n' "$BASH_BIN"; tail -n +2 "$SRC_GUARD"; } > "$work/bin/fleet-spawn-guard"
            { printf '#!%s\n' "$BASH_BIN"; tail -n +2 "$SRC_FLEET"; } > "$work/bin/fleet"
            chmod +x "$work/bin/fleet-spawn-guard" "$work/bin/fleet"
            GUARD=$work/bin/fleet-spawn-guard
            FLEET=$work/bin/fleet
            PATH="$work/bin:$PATH"
            export PATH

            pass=0
            fail() { echo "guard-selftest: FAIL $*"; exit 1; }
            ok() { echo "guard-selftest: ok $*"; pass=$((pass + 1)); }

            RC=0
            run() { RC=0; "$@" > "$work/out" 2> "$work/err" || RC=$?; }

            newdir() { mkdir -p "$work/$1"; printf '%s\n' "$work/$1"; }
            set_inv() { printf '%s\n' "$1" > "$FAKE_INV"; }
            row() { # id cwd name kind state [pid]
              if [ -n "''${6:-}" ]; then
                printf '{"id":"%s","sessionId":"%s-0000-0000","cwd":"%s","name":"%s","kind":"%s","state":"%s","pid":%s}' \
                  "$1" "$1" "$2" "$3" "$4" "$5" "$6"
              else
                printf '{"id":"%s","sessionId":"%s-0000-0000","cwd":"%s","name":"%s","kind":"%s","state":"%s"}' \
                  "$1" "$1" "$2" "$3" "$4" "$5"
              fi
            }
            # The daemon reports no `state` for some rows and no `pid` for others; neither absence
            # may be read as "this directory is free".
            row_nostate() { # id cwd name kind pid
              printf '{"id":"%s","sessionId":"%s-0000-0000","cwd":"%s","name":"%s","kind":"%s","pid":%s}' \
                "$1" "$1" "$2" "$3" "$4" "$5"
            }

            # One process that stays alive for the whole run, and one pid that is definitively gone.
            ( exec sleep 900 ) > /dev/null 2>&1 &
            LIVE_PID=$!
            export FAKE_LIVE_PID=$LIVE_PID
            ( exec sleep 900 ) > /dev/null 2>&1 &
            DEAD_PID=$!
            kill -9 "$DEAD_PID" 2> /dev/null || true
            wait "$DEAD_PID" 2> /dev/null || true
            live_bg_count() { # $1 dir
              jq -r --arg d "$1" '[.[] | select(.kind=="background" and .cwd==$d and .state=="working")] | length' "$FAKE_INV"
            }
            RAN_MARKER=$work/ran
            didrun() { [ -f "$RAN_MARKER" ]; }
            clear_ran() { rm -f "$RAN_MARKER"; }
            # A command that records that it ran, so "refused" can be distinguished from "ran and
            # happened to change nothing". Only for cases that must be REFUSED: a command that
            # registers no session would otherwise sit out the confirmation wait.
            MARK=(touch "$RAN_MARKER")

            # The allowed path has to dispatch something the fake daemon then reports, because the
            # guard does not let go until the directory answers "live" -- which is the property
            # being tested, not an inconvenience to work around.
            dispatch_into() {
              export FAKE_DISPATCH_SECONDS=0
              run "$GUARD" guard --dir "$1" -- claude --bg -n probe
              unset FAKE_DISPATCH_SECONDS
            }

            # ------------------------------------------------- P1: a live session refuses a spawn
            d=$(newdir d1)
            set_inv "[$(row aaaaaaaa "$d" incumbent background working "$LIVE_PID")]"
            clear_ran
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "P1: wanted refusal 1, got $RC -- $(cat "$work/out" "$work/err")"
            grep -q 'aaaaaaaa' "$work/out" || fail "P1: the refusal does not name the session -- $(cat "$work/out")"
            grep -q 'incumbent' "$work/out" || fail "P1: the refusal does not name the session's name"
            if didrun; then fail "P1: refused, but the guarded command ran anyway"; fi
            ok "P1 a live worker session refuses a second spawn, names it, and runs nothing"

            # ---------------------------------------- P4: a refusal displaces nothing
            before=$(cat "$FAKE_INV")
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "P4: wanted refusal 1, got $RC"
            [ "$(cat "$FAKE_INV")" = "$before" ] || fail "P4: the contender changed the incumbent's session"
            ok "P4 a refused contender leaves the live session exactly as it was"

            # ------------------------------- P2: a finished session releases the directory
            d=$(newdir d2)
            set_inv "[$(row bbbbbbbb "$d" finished background done)]"
            dispatch_into "$d"
            [ "$RC" -eq 0 ] || fail "P2: a directory whose only session is done must be free, got $RC -- $(cat "$work/out" "$work/err")"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "P2: allowed, but nothing was dispatched"
            ok "P2 a session that has finished no longer holds its directory, with no cleanup step"

            # ------------------------------- a live session in ANOTHER directory is irrelevant
            d=$(newdir d3)
            other=$(newdir d3-other)
            set_inv "[$(row cccccccc "$other" elsewhere background working)]"
            dispatch_into "$d"
            [ "$RC" -eq 0 ] || fail "other-dir: a worker elsewhere must not block this directory, got $RC"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "other-dir: allowed, but nothing was dispatched"
            ok "a live worker in another directory does not block this one"

            # ------------------- SCOPE: an interactive session in the directory does NOT block
            # The orchestrator's own session sits in the project directory. If that counted, no
            # worker could ever be dispatched into the project at all. This is also the honest
            # boundary of the guard: it governs dispatched worker sessions and nothing else.
            d=$(newdir d4)
            set_inv "[$(row dddddddd "$d" orchestrator interactive working)]"
            dispatch_into "$d"
            [ "$RC" -eq 0 ] || fail "scope: an interactive session must not block a spawn, got $RC"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "scope: allowed, but nothing was dispatched"
            ok "an interactive session does not block a spawn (and is not what this guards)"

            # ----------------------------------- fail closed: an unrecognised state counts as live
            d=$(newdir d5)
            set_inv "[$(row eeeeeeee "$d" mystery background teleporting "$LIVE_PID")]"
            clear_ran
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "fail-closed state: an unknown state must refuse, got $RC -- $(cat "$work/out")"
            if didrun; then fail "fail-closed state: refused, but the guarded command ran"; fi
            ok "a session state this guard does not recognise counts as live and refuses"

            # ------------------------------- fail closed: an unreadable authority refuses, loudly
            d=$(newdir d6)
            set_inv "[]"
            clear_ran
            export FAKE_AUTHORITY_BROKEN=1
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            unset FAKE_AUTHORITY_BROKEN
            [ "$RC" -eq 2 ] || fail "fail-closed authority: wanted a loud 2, got $RC"
            if didrun; then fail "fail-closed authority: the check never ran, but the command did"; fi
            [ ! -s "$work/out" ] || fail "fail-closed authority: wrote to stdout, where refusals live"
            grep -q 'inventory' "$work/err" || fail "fail-closed authority: stderr does not say what failed"
            clear_ran
            export FAKE_AUTHORITY_GARBAGE=1
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            unset FAKE_AUTHORITY_GARBAGE
            [ "$RC" -eq 2 ] || fail "fail-closed authority: non-JSON answer wanted a loud 2, got $RC"
            if didrun; then fail "fail-closed authority: non-JSON answer still dispatched"; fi
            ok "an inventory that cannot be read, or is not JSON, refuses loudly and dispatches nothing"

            # ------------------------------------------- the guarded command's own failure is its own
            d=$(newdir d7)
            set_inv "[]"
            export FAKE_DISPATCH_FAIL=1
            run "$GUARD" guard --dir "$d" -- "$work/bin/claude" --bg
            unset FAKE_DISPATCH_FAIL
            [ "$RC" -eq 3 ] || fail "command failure: wanted 3, got $RC -- $(cat "$work/out" "$work/err")"
            grep -q '7' "$work/out" || fail "command failure: the command's own status is not reported"
            ok "a guarded command that fails is reported as itself, not as a refusal"

            # -------------------------- a dispatch the authority never confirms is loud, not silent
            d=$(newdir d8)
            set_inv "[]"
            export FAKE_DISPATCH_SILENT=1 FAKE_DISPATCH_SECONDS=0
            run "$GUARD" guard --dir "$d" -- "$work/bin/claude" --bg
            unset FAKE_DISPATCH_SILENT FAKE_DISPATCH_SECONDS
            [ "$RC" -eq 4 ] || fail "unconfirmed: wanted 4, got $RC -- $(cat "$work/out" "$work/err")"
            grep -qi 'unguarded' "$work/out" || fail "unconfirmed: the operator is not told a worker may be loose"
            ok "a dispatch the daemon never confirms exits 4 and says a worker may be running unguarded"

            # ------------------------------------------ the lock does not outlive the guard
            # A child that inherits the lock fd inherits the lock. If that happens the next spawn
            # blocks on a directory nobody is working in.
            d=$(newdir d9)
            set_inv "[]"
            export FAKE_DISPATCH_LINGER=1 FAKE_DISPATCH_SECONDS=0
            run "$GUARD" guard --dir "$d" -- "$work/bin/claude" --bg
            unset FAKE_DISPATCH_LINGER FAKE_DISPATCH_SECONDS
            [ "$RC" -eq 0 ] || fail "fd-leak: setup dispatch wanted 0, got $RC -- $(cat "$work/err")"
            lrc=0
            ( exec 9< "$d"; flock -n -x 9 ) > /dev/null 2>&1 || lrc=$?
            [ "$lrc" -eq 0 ] || fail "fd-leak: the directory is still locked after the guard exited (a child inherited the lock)"
            ok "the lock is released when the guard exits, even if the dispatch left a child running"

            # ----------------------------- P2: a `blocked` session whose process is gone
            # `blocked` never becomes a finished state on its own. Without the process check its
            # directory is unspawnable forever and the only cure is deleting the row by hand, which
            # is precisely what P2 forbids -- and this repository has a session that sat `blocked`
            # for six weeks. A guard that can permanently wedge a directory is worse than no guard,
            # because today a spawn always succeeds.
            d=$(newdir d12)
            set_inv "[$(row 11111111 "$d" wedged background blocked "$DEAD_PID")]"
            dispatch_into "$d"
            [ "$RC" -eq 0 ] || fail "P2-blocked: a blocked session whose process is gone must release its directory, got $RC -- $(cat "$work/out" "$work/err")"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "P2-blocked: allowed, but nothing was dispatched"
            ok "P2 a blocked session whose process is gone no longer holds its directory"

            # ----------------------------- P1: a `blocked` session whose process is alive
            # The other half of the same rule. A worker parked on a permission prompt is still
            # there and can still resume and write, so it must keep its directory.
            d=$(newdir d13)
            set_inv "[$(row 22222222 "$d" parked background blocked "$LIVE_PID")]"
            clear_ran
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "P1-blocked: a blocked session that is still running must keep its directory, got $RC"
            if didrun; then fail "P1-blocked: refused, but the guarded command ran"; fi
            ok "P1 a blocked session whose process is still running keeps its directory"

            # ----------------------------- fail closed: a row with no pid counts live
            d=$(newdir d14)
            set_inv "[$(row 33333333 "$d" pidless background blocked)]"
            clear_ran
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "no-pid: a row that reports no pid must count live, got $RC"
            if didrun; then fail "no-pid: refused, but the guarded command ran"; fi
            ok "a session row that reports no pid counts live, not free"

            # ----------------------------- fail closed: a row with no state counts live
            # Process-backed rows carry no `state` at all. An absent field must not be the thing
            # that frees a directory.
            d=$(newdir d15)
            set_inv "[$(row_nostate 44444444 "$d" stateless background "$LIVE_PID")]"
            clear_ran
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            [ "$RC" -eq 1 ] || fail "no-state: a row with no state but a running process must count live, got $RC"
            if didrun; then fail "no-state: refused, but the guarded command ran"; fi
            ok "a session row with no state, whose process is running, counts live"

            # ----------------------- a daemon that never answers must not park the holder
            # The read happens while the directory lock is held, so an unbounded read parks this
            # spawn and every later one behind it. The outer timeout is the test's own bound: if
            # the guard does not bound its read, it is what ends this case, and the exit code says so.
            d=$(newdir d16)
            set_inv "[]"
            clear_ran
            export FAKE_AUTHORITY_HANG=1
            t0=$(date +%s)
            RC=0
            timeout 45 "$GUARD" guard --dir "$d" -- "''${MARK[@]}" > "$work/out" 2> "$work/err" || RC=$?
            t1=$(date +%s)
            unset FAKE_AUTHORITY_HANG
            [ "$RC" -eq 2 ] || fail "hang: wanted a loud 2, got $RC (124 means the guard never bounded its own read)"
            [ $((t1 - t0)) -lt 35 ] || fail "hang: the guard waited $((t1 - t0))s before giving up"
            if didrun; then fail "hang: dispatched without ever getting an answer"; fi
            ok "a daemon that accepts the question and never answers fails closed, bounded, and dispatches nothing"

            # ----------------------- an inventory whose rows were renamed is not an empty one
            d=$(newdir d17)
            clear_ran
            export FAKE_AUTHORITY_RENAMED=1
            run "$GUARD" guard --dir "$d" -- "''${MARK[@]}"
            unset FAKE_AUTHORITY_RENAMED
            [ "$RC" -eq 2 ] || fail "renamed-fields: an inventory missing the fields this guard reads wanted 2, got $RC"
            if didrun; then fail "renamed-fields: read as a free directory and dispatched"; fi
            ok "an inventory whose rows lack the fields this guard reads refuses, instead of reading as free"

            # ------------------------------------------------- P1 under real contention
            # The question and the dispatch are one critical section or they are nothing: a dispatch
            # takes seconds and the session appears only at the end of it, so two guards that merely
            # take turns ASKING both see an empty directory and both dispatch. That is the original
            # incident. Both contenders are released by a flock barrier in the same instant.
            d=$(newdir d10)
            set_inv "[]"
            res=$work/race; rm -rf "$res"; mkdir -p "$res"
            : > "$d.gate"
            exec 8> "$d.gate"
            flock -x 8
            cs=""
            for i in 1 2; do
              ( flock -s 7
                rc=0
                FAKE_DISPATCH_SECONDS=2 FAKE_NAME="racer$i" \
                  "$GUARD" guard --dir "$d" -- claude --bg -n "racer$i" > "$res/$i.out" 2>&1 || rc=$?
                echo "$rc" > "$res/$i.rc" ) 7< "$d.gate" 8>&- &
              cs="$cs $!"
            done
            sleep 0.3
            exec 8>&-
            for p in $cs; do wait "$p" || true; done
            won=0
            refused=0
            recorded=0
            for f in "$res"/*.rc; do
              [ -f "$f" ] || continue
              recorded=$((recorded + 1))
              r=$(cat "$f")
              if [ "$r" = "0" ]; then won=$((won + 1)); fi
              if [ "$r" = "1" ]; then refused=$((refused + 1)); fi
            done
            [ "$recorded" -eq 2 ] || fail "P1-contended: only $recorded of 2 contenders recorded a result"
            [ "$won" -eq 1 ] || fail "P1-contended: $won of 2 contenders dispatched, wanted exactly 1 -- $(cat "$res"/*.out)"
            [ "$refused" -eq 1 ] || fail "P1-contended: $refused of 2 contenders were refused, wanted exactly 1"
            n=$(live_bg_count "$d")
            [ "$n" -eq 1 ] || fail "P1-contended: the directory ended with $n live worker sessions, wanted exactly 1"
            ok "P1 two simultaneous spawns into one directory: exactly one dispatches, exactly one is refused"

            # --------------------------------------------------------------------- status
            d=$(newdir d11)
            set_inv "[$(row ffffffff "$d" busyone background working)]"
            run "$GUARD" status --dir "$d"
            [ "$RC" -eq 0 ] || fail "status: a directory with a live session wanted 0, got $RC"
            grep -q 'busyone' "$work/out" || fail "status: does not name the session"
            set_inv "[$(row ffffffff "$d" goneone background done)]"
            run "$GUARD" status --dir "$d"
            [ "$RC" -eq 1 ] || fail "status: a directory whose session finished wanted 1, got $RC"
            ok "status reports a live worker session, and reports free once it has finished"

            # ------------------------------------------------------------- usage is loud
            set_inv "[]"
            run "$GUARD" guard --dir "$work" --bogus -- true
            [ "$RC" -eq 2 ] || fail "usage: an unknown option wanted 2, got $RC"
            [ ! -s "$work/out" ] || fail "usage: a usage error wrote to stdout, where refusals live"
            grep -q 'unknown option' "$work/err" || fail "usage: stderr does not explain the misuse"
            run "$GUARD" guard --dir "$work/does-not-exist" -- true
            [ "$RC" -eq 2 ] || fail "usage: a missing directory wanted 2, got $RC"
            run "$GUARD" guard --dir "$work"
            [ "$RC" -eq 2 ] || fail "usage: no command after -- wanted 2, got $RC"
            run "$GUARD" nonsense --dir "$work"
            [ "$RC" -eq 2 ] || fail "usage: an unknown subcommand wanted 2, got $RC"
            ok "a usage error exits 2, says so on stderr, and never looks like a refusal"

            # ------------------------------------------- the incident, through fleet spawn
            printf '## Boundary\nb\n\n## Termination condition\nt\n\n## Output\no\n' > "$work/spec.md"
            d=$(newdir wk)
            set_inv "[]"
            export FAKE_DISPATCH_SECONDS=0
            run "$FLEET" spawn --name first --dir "$d" --spec "$work/spec.md"
            [ "$RC" -eq 0 ] || fail "fleet: the first spawn wanted 0, got $RC -- $(cat "$work/err")"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "fleet: the first spawn did not register a session"
            run "$FLEET" spawn --name second --dir "$d" --spec "$work/spec.md"
            [ "$RC" -ne 0 ] || fail "fleet: a SECOND worker was dispatched into a directory already being worked in"
            [ "$(live_bg_count "$d")" -eq 1 ] || fail "fleet: the directory now has $(live_bg_count "$d") live sessions"
            grep -qi 'already has a live worker session' "$work/out" "$work/err" \
              || fail "fleet: the refusal does not say why -- $(cat "$work/out" "$work/err")"
            ok "fleet spawn refuses a second worker where one is already working"

            if [ "$pass" -eq 0 ]; then
              echo "guard-selftest: no cases ran"
              exit 1
            fi
            kill -9 "$LIVE_PID" 2> /dev/null || true
            echo "guard-selftest: $pass case(s) asserted"

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

