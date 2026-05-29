#!/bin/bash
# UserPromptSubmit hook: when the prompt contains the sentinel `@clip`,
# extract the current Windows clipboard image via PowerShell, save it to
# ~/.claude/paste-cache/, and tell the model where it lives via
# additionalContext. WSL-only; silently no-ops elsewhere.

set -u

SENTINEL='@clip'
CACHE_DIR="${HOME}/.claude/paste-cache"

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')

case "$prompt" in
  *"$SENTINEL"*) ;;
  *) exit 0 ;;
esac

command -v powershell.exe >/dev/null 2>&1 || exit 0
command -v wslpath        >/dev/null 2>&1 || exit 0

mkdir -p "$CACHE_DIR"
filename="clip-$(date +%Y%m%d-%H%M%S-%N).png"
linux_path="${CACHE_DIR}/${filename}"
win_path=$(wslpath -w "$linux_path")
win_path_escaped=${win_path//\\/\\\\}

ps_script=$(cat <<PS
Add-Type -AssemblyName System.Windows.Forms
\$img = [System.Windows.Forms.Clipboard]::GetImage()
if (\$img) {
  \$img.Save('${win_path_escaped}', [System.Drawing.Imaging.ImageFormat]::Png)
  exit 0
} else {
  exit 1
}
PS
)

if ! powershell.exe -sta -NoProfile -Command "$ps_script" >/dev/null 2>&1; then
  jq -n --arg s "$SENTINEL" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "Sentinel \($s) was used but the Windows clipboard did not contain an image. Ask the user to copy an image (e.g. Win+Shift+S) and try again."
    }
  }'
  exit 0
fi

jq -n --arg p "$linux_path" --arg s "$SENTINEL" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: "Sentinel \($s) triggered a Windows→WSL clipboard image bridge. The image is saved at: \($p)\nRead this file to see what the user pasted."
  }
}'
