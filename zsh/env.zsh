# Zsh environment variables
# This file is sourced on all invocations of the shell

# Ensure path arrays are unique
typeset -U path fpath

# Tool-specific environment variables
export PROTO_HOME="$XDG_DATA_HOME/proto"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"
export STARSHIP_CACHE="$XDG_CACHE_HOME/starship"
export SHELDON_CONFIG_DIR="$XDG_CONFIG_HOME/sheldon"
export SHELDON_DATA_DIR="$XDG_DATA_HOME/sheldon"
export GHQ_ROOT="$HOME/src"
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# Zsh history settings
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

# Default applications
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# Less options
export LESS="-FRX"

# FZF options
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Homebrew on Linux
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Add various paths
path=(
    "$HOME/.local/bin"
    "$CARGO_HOME/bin"
    "$PROTO_HOME/shims"
    "$PROTO_HOME/bin"
    "$HOME/.cache/.bun/bin"
    $path
)