#!/usr/bin/env zsh
# zsh-abbr initialization script

# Only proceed if zsh-abbr is loaded
if (( ! ${+functions[abbr]} )); then
    echo "Warning: zsh-abbr is not loaded. Skipping abbreviations setup." >&2
    return 0
fi

# Set the abbreviations file path
local abbr_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-abbr"
local user_abbr_file="${abbr_config_dir}/user-abbreviations"

# Check if user abbreviations file exists
if [[ ! -f "$user_abbr_file" ]]; then
    echo "Info: No user abbreviations file found at $user_abbr_file" >&2
    return 0
fi

# Source the user abbreviations file
# The file should contain abbr commands without the need for additional processing
source "$user_abbr_file"