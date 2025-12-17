#!/usr/bin/env bash
# copy-workspace-files.sh
# Copies configured files from source to workspace directory

set -euo pipefail

# Usage: copy-workspace-files.sh <source_dir> <dest_dir>
if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_dir> <dest_dir>" >&2
    exit 1
fi

SOURCE_DIR="$1"
DEST_DIR="$2"

# Configuration file locations (in order of priority)
CONFIG_FILES=(
    "$SOURCE_DIR/.config-workspace-files"
    "$HOME/.config/workspace/files.conf"
    "$SOURCE_DIR/.config-workspace-files.example"
)

# Find the first existing config file
CONFIG_FILE=""
for conf in "${CONFIG_FILES[@]}"; do
    if [ -f "$conf" ]; then
        CONFIG_FILE="$conf"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    # No config file found, exit silently (this is optional feature)
    exit 0
fi

# Read config file and copy files
copied_count=0
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Remove leading/trailing whitespace
    file_path=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    source_file="$SOURCE_DIR/$file_path"
    dest_file="$DEST_DIR/$file_path"

    if [ -f "$source_file" ]; then
        # Create destination directory if needed
        dest_dir=$(dirname "$dest_file")
        mkdir -p "$dest_dir"

        # Copy the file
        cp -p "$source_file" "$dest_file"
        echo "✓ Copied: $file_path"
        ((copied_count++))
    elif [ -e "$source_file" ]; then
        echo "⚠ Skipped (not a file): $file_path" >&2
    else
        echo "⚠ Skipped (not found): $file_path" >&2
    fi
done < "$CONFIG_FILE"

if [ $copied_count -gt 0 ]; then
    echo ""
    echo "📋 Copied $copied_count file(s) to workspace"
fi

exit 0
