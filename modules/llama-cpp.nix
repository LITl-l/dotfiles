{ pkgs, lib, ... }:

let
  # Prism ML Bonsai 27B ternary quant. llama-server's -hf flag lazily
  # downloads the GGUF into ~/.cache/llama.cpp on first launch and reuses it
  # thereafter, so we don't need a Nix-managed weights derivation.
  hfRepo = "prism-ml/Ternary-Bonsai-27B-gguf";
  hfQuant = "Q2_0";
  host = "127.0.0.1";
  port = 8080;
in
{
  # Local Bonsai 27B inference exposed as an OpenAI-compatible endpoint at
  # http://127.0.0.1:8080/v1. Pi's local-llama provider (see modules/pi.nix)
  # points at this service.
  systemd.user.services.llama-server = {
    Unit = {
      Description = "llama.cpp OpenAI-compatible server (Bonsai 27B)";
      Documentation = [ "https://github.com/ggml-org/llama.cpp" ];
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.llama-cpp}/bin/llama-server"
        "-hf ${hfRepo}:${hfQuant}"
        "--host ${host}"
        "--port ${toString port}"
        "-c 0"
        "--jinja"
        "--alias bonsai-27b"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
