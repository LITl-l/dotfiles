{ config, pkgs, lib, ... }:

{
  programs.jujutsu = {
    enable = true;

    settings = {
      # User identity: set via `jj config set --user user.name "Your Name"`
      # or create ~/.jjconfig.toml manually

      # UI preferences
      ui = {
        editor = "nvim";
        pager = "delta";
        diff.format = "git";
      };

      # Git backend settings
      git = {
        auto-local-branch = true;

        # jj 0.46.0 以降、`jj workspace add` は既定でワークスペースごとに
        # git worktree を作る (git.colocate = true)。その worktree のリンクは
        # 相対パスで書かれ、共有の .git/config に extensions.relativeWorktrees が立つ。
        # libgit2 はこの拡張に未対応なので、Nix の git+file:// フェッチが
        # "unsupported extension name" で失敗し、direnv / nix develop が壊れる
        # (NixOS/nix#14987, libgit2#7210)。colocated リポジトリでワークスペースを
        # 作るたびに再発し、その都度 `git worktree repair --no-relative-paths` が要る。
        # メインのチェックアウトは colocated のままで、追加ワークスペースだけ
        # git worktree を持たなくなる。上流の libgit2 が対応したら外してよい。
        colocate = false;
      };
    };
  };

  # jjui - TUI for Jujutsu VCS
  home.packages = with pkgs; [
    jjui
  ];
}
