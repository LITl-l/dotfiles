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

      # Give up after 5 failures in 5 minutes instead of restarting forever.
      # A GGUF the local llama.cpp build cannot decode fails identically on
      # every attempt, so `Restart = "on-failure"` on its own spins at
      # RestartSec forever: this unit logged 2138 restarts in one session and
      # 1212 in the next, each one a fresh process, mmap and journal write.
      # Rate-limiting turns a silent infinite loop into a visible failed unit
      # that `systemctl --user status` actually reports.
      #
      # The current weights trip exactly this case: PQ2_0 stores tensors as
      # ggml type 142, outside the [0, 43) range this build understands, so
      # loading always ends in "invalid ggml type 142". Serving Bonsai needs a
      # llama.cpp with ternary-quant support, or a quant this build can read.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
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
