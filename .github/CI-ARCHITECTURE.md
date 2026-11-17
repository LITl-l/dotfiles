# CI Architecture

This document describes the CI/CD architecture for the NixOS-based dotfiles.

## Overview

The CI pipeline is designed to validate and build NixOS configurations using GitHub Actions. It focuses exclusively on Nix-based builds and testing.

## Workflow Structure

The job-by-job detail lives in `.github/workflows/nix-check.yml`; repeating it here is
what made the previous version of this document wrong. What follows is the shape of the
pipeline and the one property that is not visible from any single job.

```
validate-flake ─┬─ flake-check ───────────────────────────────┐
                ├─ discover-modules ── test-modules (matrix) ─┼─ build-linux ──┐
                └─ test-format ───────────────────────────────┤  build-wsl     ├─ summary
                                                              └─ build-nixos-wsl
```

- **validate-flake** — flake metadata, structure, and lock file.
- **flake-check** — `nix flake check`. This is where the flake's own checks run.
- **discover-modules** — enumerates `modules/*.nix` into the matrix below.
- **test-modules** — per module: parses it, and confirms `home.nix` imports it.
- **build-linux / build-wsl / build-nixos-wsl** — build each activation package.
- **test-format** — `nix fmt --check`, non-blocking (`continue-on-error`).
- **summary** — always runs; fails unless every job it needs succeeded.

### The invariant: no list of names in the workflow

Three things used to be enumerated by hand in `nix-check.yml`, and each one silently
skipped whatever was not on its list. None of them is enumerated any more:

| What | How it is derived now |
|---|---|
| Which flake checks run | `nix flake check` reads `checks.<system>` itself |
| Which modules are tested | `discover-modules` globs `modules/*.nix` |
| Which jobs the summary reports and gates on | `toJSON(needs)` |

Adding a check, a module or a job therefore needs no edit to the workflow beyond the one
GitHub already forces (a `needs:` entry, for a job). **Do not reintroduce a hardcoded
list.** Each of the three guards against its own empty case, because an empty list is how
this class of defect reports success.

## Module-Specific Testing

For each `modules/*.nix`:

1. **Syntax check** — `nix-instantiate --parse`.
2. **Reachability check** — `home.nix` imports the file. Nothing else in CI can catch a
   module that was written and never wired in; everything else evaluates `home.nix`.

There is deliberately no isolated "evaluate the module" step. A Home Manager module
evaluated outside a config fixpoint has nothing to resolve against. The module's real
evaluation happens in `flake-check` and the three `build-*` jobs, against a real config.

## Platform Support

| Configuration | Platform | CI Testing |
|--------------|----------|------------|
| `user@linux` | Native Linux | ✅ Full build |
| `user@wsl` | WSL2 | ✅ Full build |
| `nixos@wsl` | NixOS on WSL2 | ✅ Full build |
| `user@darwin` | macOS | ❌ Not tested (NixOS focus) |

`nix flake check` reports the systems it skips (`aarch64-linux`, `x86_64-darwin`,
`aarch64-darwin`) rather than passing over them quietly.

## Caching

- Uses `cachix/cachix-action` with the `nix-community` cache.
- Read-only: `skipPush: true`, no authentication required.
- This repo's own derivations are pushed nowhere, so nothing a runner builds survives
  it. That is why `flake-check` is one job rather than a matrix — the closure the checks
  share is fetched once per job, so a job per check would fetch it once per check.

## Failure Handling

`summary` requires every job it depends on to have resulted in `success`. `skipped` and
`cancelled` fail it too: a job skipped because its dependency failed is a hole, not a
pass.

`test-format` is the one job that cannot block a merge — its formatting step carries
`continue-on-error`, so the job itself still reports success.

Module tests use `fail-fast: false`, so one module's failure does not hide the others.

## Local Testing

### Test a specific module:
```bash
nix-instantiate --parse modules/fish.nix
```

### Build a configuration:
```bash
nix build .#homeConfigurations."user@linux".activationPackage
```

### Check formatting:
```bash
nix fmt
```

### Run every check the flake defines:
```bash
nix flake check
```

### Run one check:
```bash
nix build --no-link '.#checks.x86_64-linux.crumb-tests'
```

## Extending CI

### Adding a New Module

1. Create the module file: `modules/new-module.nix`
2. Add it to `home.nix` imports

That is the whole list. CI picks the module up from the directory; the second step is
what `test-modules` asserts, and skipping it is the failure you will see.

### Adding a New Check

1. Add it to `checks` in `flake.nix`

`flake-check` runs it on the next push. Nothing in `.github/` needs to change.

### Adding a New Configuration

1. Add to `flake.nix` homeConfigurations
2. Add a build job in the CI workflow, and to `summary`'s `needs:`

## Troubleshooting

### Common Issues

**Issue**: Flake lock generation fails
**Fix**: Commit flake.lock or allow CI to generate it

**Issue**: Module syntax error
**Fix**: Run `nix-instantiate --parse modules/MODULE.nix` locally

**Issue**: Build fails with "attribute not found"
**Fix**: Check module imports in home.nix

**Issue**: A new module is reported as absent from `home.nix`
**Fix**: Add `./modules/MODULE.nix` to the `imports` list in `home.nix`. Until it is
there, no build and no flake check ever evaluates the file.

**Issue**: Cross-platform build failure
**Fix**: Ensure checks only build for matching systems (see flake.nix checks section)

## Performance

A full green run of `Nix Build CI` on `main` takes roughly 4 minutes end to end, with the
`build-*` jobs dominating and the rest running alongside them. A first run against a cold
`cache.nixos.org` is substantially longer.

## Security

- No secrets required for public repositories
- Cachix auth token optional (read-only cache works without it)
- All dependencies pinned via flake.lock
- Deterministic builds via Nix
- Matrix values derived from the branch under test reach the shell through `env:`, never
  through `${{ }}` interpolation into a script body

## Future Enhancements

Potential improvements:
- [ ] Add integration tests for Fish shell functions
- [x] Test Neovim plugin loading — `checks.nvim-config-tests` starts a real headless
      neovim against `nvim/init.lua`
- [x] Validate WezTerm config with Lua linter — `checks.wezterm-lua-syntax` runs
      `luac -p` over every `wezterm/*.lua`
- [ ] Add performance benchmarks
- [ ] Test configuration rollback scenarios
- [ ] Add security scanning for dependencies
