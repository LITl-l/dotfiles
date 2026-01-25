# CI Architecture

This document describes the CI/CD architecture for the NixOS-based dotfiles.

## Overview

The CI pipeline is designed to validate and build NixOS configurations using GitHub Actions. It focuses exclusively on Nix-based builds and testing.

## Workflow Structure

### Jobs

1. **validate-flake** (Required)
   - Validates flake syntax and structure
   - Shows flake metadata
   - Checks flake inputs
   - Generates lock file if needed

2. **test-modules** (Required, Matrix Job)
   - Tests each module individually
   - Validates syntax with `nix-instantiate`
   - Evaluates module loading
   - Runs for: fish, wezterm, neovim, starship, git, common

3. **build-linux** (Required)
   - Builds `user@linux` Home Manager configuration
   - Validates activation package
   - Tests full Linux setup

4. **build-wsl** (Required)
   - Builds `user@wsl` Home Manager configuration
   - Validates WSL-specific settings
   - Tests WSL2 setup

5. **test-format** (Optional)
   - Checks Nix code formatting
   - Non-blocking (continue-on-error)

6. **test-nvim-config** (Required)
   - Validates Neovim configuration files
   - Checks Lua modules

7. **test-wezterm-config** (Required)
   - Validates WezTerm configuration
   - Checks OS detection logic

8. **summary** (Always runs)
   - Summarizes all job results
   - Fails if critical jobs fail

## Module-Specific Testing

Each module in `modules/` is tested individually:

```
modules/
├── common.nix      → Common settings across platforms
├── fish.nix        → Fish shell configuration
├── git.nix         → Git and Lazygit setup
├── neovim.nix      → Neovim with packages
├── starship.nix    → Starship prompt
└── wezterm.nix     → WezTerm terminal
```

### Test Process

For each module:
1. **Syntax Check**: `nix-instantiate --parse`
2. **Evaluation Check**: Load module with mock inputs
3. **Integration Check**: Build full configuration

## Platform Support

| Configuration | Platform | CI Testing |
|--------------|----------|------------|
| `user@linux` | Native Linux | ✅ Full build |
| `user@wsl` | WSL2 | ✅ Full build |
| `user@darwin` | macOS | ❌ Not tested (NixOS focus) |

## Caching

- Uses `cachix/cachix-action` with `nix-community` cache
- Significantly speeds up builds
- No authentication required (read-only)

## Failure Handling

### Critical Jobs
These jobs MUST pass:
- validate-flake
- test-modules (all modules)
- build-linux
- build-wsl
- test-nvim-config
- test-wezterm-config

### Non-Critical Jobs
These jobs are optional:
- test-format (formatting can be fixed later)

### Matrix Jobs
Module tests use `fail-fast: false`, allowing other modules to be tested even if one fails.

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

### Validate flake:
```bash
nix flake check
```

## Extending CI

### Adding a New Module

1. Create module file: `modules/new-module.nix`
2. Add to `home.nix` imports
3. Add to CI matrix in `.github/workflows/nix-check.yml`:
   ```yaml
   matrix:
     module:
       - fish
       - wezterm
       - new-module  # Add here
   ```

### Adding a New Configuration

1. Add to `flake.nix` homeConfigurations
2. Add build job in CI workflow
3. Update checks section in flake.nix

## Troubleshooting

### Common Issues

**Issue**: Flake lock generation fails
**Fix**: Commit flake.lock or allow CI to generate it

**Issue**: Module syntax error
**Fix**: Run `nix-instantiate --parse modules/MODULE.nix` locally

**Issue**: Build fails with "attribute not found"
**Fix**: Check module imports in home.nix

**Issue**: Cross-platform build failure
**Fix**: Ensure checks only build for matching systems (see flake.nix checks section)

## Performance

Typical CI run times:
- validate-flake: ~1 minute
- test-modules: ~2 minutes (parallel)
- build-linux: ~5-10 minutes (with cache)
- build-wsl: ~5-10 minutes (with cache)
- Total: ~10-15 minutes

First run (no cache): ~30-45 minutes

## Security

- No secrets required for public repositories
- Cachix auth token optional (read-only cache works without it)
- All dependencies pinned via flake.lock
- Deterministic builds via Nix

## Future Enhancements

Potential improvements:
- [ ] Add integration tests for Fish shell functions
- [ ] Test Neovim plugin loading
- [ ] Validate WezTerm config with Lua linter
- [ ] Add performance benchmarks
- [ ] Test configuration rollback scenarios
- [ ] Add security scanning for dependencies
