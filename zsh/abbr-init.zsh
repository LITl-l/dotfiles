#!/usr/bin/env zsh
# zsh-abbr initialization script

# Only proceed if zsh-abbr is loaded
if (( ! ${+functions[abbr]} )); then
    return 0
fi

# Set the abbreviations file path
local abbr_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-abbr"
local user_abbr_file="${abbr_config_dir}/user-abbreviations"
local source_abbr_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/user-abbreviations"

# Create zsh-abbr config directory if it doesn't exist
[[ ! -d "$abbr_config_dir" ]] && mkdir -p "$abbr_config_dir"

# Copy user abbreviations to zsh-abbr config directory if source exists
if [[ -f "$source_abbr_file" && "$source_abbr_file" -nt "$user_abbr_file" ]]; then
    cp "$source_abbr_file" "$user_abbr_file"
fi

# Check if user abbreviations file exists
if [[ ! -f "$user_abbr_file" ]]; then
    return 0
fi

# Note: Don't source the user abbreviations file here
# The zsh-abbr plugin will automatically load from ~/.config/zsh-abbr/user-abbreviations
# Sourcing it here would cause duplicate abbreviation warnings