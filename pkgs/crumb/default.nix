{ buildGoModule, lib }:

buildGoModule {
  pname = "crumb";
  version = "0.1.0";

  src = ./.;

  # No third-party modules — the whole tool is Go standard library.
  vendorHash = null;

  # Run `go test ./...` in the check phase so `nix build`/`nix flake check`
  # exercise the unit + protocol tests.
  doCheck = true;

  ldflags = [ "-s" "-w" "-X main.version=0.1.0" ];

  meta = {
    description = "Zero-dependency context store-and-stub: MCP server + CLI";
    longDescription = ''
      crumb stores large content out of an agent's context window (content-addressed,
      locally) and returns a short stub the agent can follow back with the retrieve
      tool. Pure Go standard library; no ML, no network, no telemetry.
    '';
    mainProgram = "crumb";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
