{
  description = "TRS toolchain (pinned by flake.lock)";

  # バージョンの固定は flake.lock が担う。更新は `nix flake update` を PR で人がレビューする。
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAll (pkgs: {
        trs = pkgs.python3Packages.buildPythonApplication {
          pname = "trs";
          version = "2.0.0";
          pyproject = true;
          src = ./tools/trs;
          build-system = [ pkgs.python3Packages.setuptools ];
          dependencies = with pkgs.python3Packages; [ z3-solver pyyaml jsonschema ];
          nativeCheckInputs = [ pkgs.python3Packages.pytestCheckHook pkgs.tlaplus ];
          preCheck = "export TRS_TLC=tlc";
        };
        default = self.packages.${pkgs.system}.trs;
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ self.packages.${pkgs.system}.trs pkgs.tlaplus pkgs.python3Packages.pytest ];
          TRS_TLC = "tlc";
        };
      });
    };
}
