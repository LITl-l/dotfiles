#!/usr/bin/env zsh

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Zsh configuration directory
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Path additions
export PATH="$HOME/.local/bin:$PATH"

# Source the rest of zsh configuration from XDG config
if [ -f "$ZDOTDIR/.zshenv" ]; then
    source "$ZDOTDIR/.zshenv"
fi
. "$HOME/.cargo/env"
