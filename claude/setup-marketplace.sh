#!/usr/bin/env bash
# Install the Claude Code plugins that claude/settings.json enables.
#
# `enabledPlugins` in settings.json is the single source of truth. It is tracked in
# this repo, but enabling a plugin there only TOGGLES it -- the CLI still has to
# fetch it. This script closes that gap: it installs every enabled entry belonging
# to a marketplace declared below, and nothing else.
#
# home.activation.setupClaudeCode runs it on every `home-manager switch`, so it
# must be idempotent (install only what is missing -- never uninstall/reinstall),
# must not hang (a stalled network would hang the switch), must not fail the
# switch, and must leave the tracked settings.json byte-identical.
#
# Environment:
#   CLAUDE_BIN                 claude CLI to use (default: `claude` from PATH)
#   CLAUDE_MARKETPLACE_PATH    local marketplace directory
#   CLAUDE_SETTINGS_FILE       settings.json to read enabledPlugins from
#   CLAUDE_SETUP_TIMEOUT       per-CLI-call deadline in seconds (default 120)
#   CLAUDE_SETUP_KILL_GRACE    SIGKILL grace after that deadline (default 10)
#
# Usage:
#   ./setup-marketplace.sh              # add marketplaces, install what is missing
#   ./setup-marketplace.sh --update     # refresh marketplace sources first, then the above
#   ./setup-marketplace.sh --uninstall  # remove the plugins, marketplaces and MCP servers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths into the dotfiles checkout. home.activation passes these in as absolute
# paths so the canonical checkout is used even when this script is executed out of
# a throwaway jj workspace: `claude plugin marketplace add` records the directory
# it is handed in Claude Code's state, and a workspace path disappears.
MARKETPLACE_PATH="${CLAUDE_MARKETPLACE_PATH:-$SCRIPT_DIR/marketplaces/local}"
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$SCRIPT_DIR/settings.json}"

# Absolute store path during home-manager activation (the new generation's bin/ is
# not on PATH there), plain `claude` from a terminal.
CLAUDE="${CLAUDE_BIN:-claude}"

# Deadline for every CLI call, so a stalled network cannot hang a switch, plus the
# grace period before a child that ignored SIGTERM is SIGKILLed.
NET_TIMEOUT="${CLAUDE_SETUP_TIMEOUT:-120}"
KILL_GRACE="${CLAUDE_SETUP_KILL_GRACE:-10}"

# Set once any CLI call hits its deadline. A per-call timeout bounds one call, not
# the run: on a machine with a stalled network, N missing plugins x NET_TIMEOUT is
# that much `home-manager switch`. Once the network has proven dead, stop calling.
TIMED_OUT=0

# Marketplaces this script owns. Entries in enabledPlugins from any other
# marketplace -- notably the claude.ai org-synced `osi-deploy` -- are installed and
# updated elsewhere, so they are skipped rather than installed here.
DECLARED_MARKETPLACES=(local claude-plugins-official)
OFFICIAL_MARKETPLACE="anthropics/claude-plugins-official"

# Remote MCP servers registered at user scope (not bundled as plugins).
# context7: streamable-HTTP remote MCP. Replaces the npx @upstash/context7-mcp
# plugin, whose server targets context7.com (unreachable here -> the hangs). The
# remote host mcp.context7.com responds without spawning a local Node process.
# Optional: export CONTEXT7_API_KEY before running for higher rate limits.
CONTEXT7_MCP_URL="https://mcp.context7.com/mcp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# info -> stdout, warn/error -> stderr, so activation can silence the chatter with
# a plain `>/dev/null` and still surface failures.
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Run a claude CLI call that must never abort the caller. Covers both the
# `set -euo pipefail` footgun (a re-added marketplace exits non-zero) and a hung
# network. A deadline hit is recorded in TIMED_OUT so the callers can stop early
# instead of waiting out one deadline per remaining plugin.
try() {
  local rc=0
  timeout -k "$KILL_GRACE" "$NET_TIMEOUT" "$CLAUDE" "$@" || rc=$?
  # 124: killed at the deadline. 137: SIGKILLed afterwards, i.e. it ignored SIGTERM.
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    TIMED_OUT=1
    warn "claude $* timed out after ${NET_TIMEOUT}s"
  elif [[ $rc -ne 0 ]]; then
    warn "claude $* failed (exit $rc)"
  fi
  return 0
}

# True once a deadline has been hit; callers use it to bail out of their loops.
timed_out() {
  if [[ $TIMED_OUT -eq 1 ]]; then
    warn "a CLI call already hit the ${NET_TIMEOUT}s deadline; skipping the rest"
    return 0
  fi
  return 1
}

check_prereqs() {
  if ! command -v "$CLAUDE" >/dev/null 2>&1; then
    error "claude CLI not found (CLAUDE_BIN=${CLAUDE_BIN:-unset})"
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    error "jq not found; it is needed to read enabledPlugins from settings.json"
    exit 1
  fi
  # Assert the settings file up front. Without this a missing or malformed file
  # reads as "nothing is enabled" and the script exits 0 having done nothing.
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    error "settings.json not found: $SETTINGS_FILE"
    exit 1
  fi
  if ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
    error "settings.json is not valid JSON: $SETTINGS_FILE"
    exit 1
  fi
}

marketplace_re() {
  local IFS='|'
  echo "${DECLARED_MARKETPLACES[*]}"
}

# Every enabledPlugins key, or only the enabled ones with `enabled`, restricted to
# the marketplaces declared above.
#
# The `|| true` is scoped to grep alone: grep exits 1 when nothing matches, which
# is a normal result here, while jq failing on a malformed settings.json must NOT
# be swallowed into an empty list. check_prereqs validates the file as well.
declared_plugins() {
  local filter='.enabledPlugins // {} | to_entries[] | .key'
  if [[ "${1:-}" == "enabled" ]]; then
    filter='.enabledPlugins // {} | to_entries[] | select(.value) | .key'
  fi
  jq -r "$filter" "$SETTINGS_FILE" | { grep -E "@($(marketplace_re))\$" || true; } | sort
}

# enabledPlugins entries from marketplaces this script does not own.
foreign_plugins() {
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$SETTINGS_FILE" \
    | { grep -vE "@($(marketplace_re))\$" || true; } | sort
}

# Non-zero when the CLI call fails, so "could not ask" is never mistaken for
# "nothing is installed" -- that mistake reinstalls every plugin on every switch.
installed_plugins() {
  local out
  out="$(timeout -k "$KILL_GRACE" "$NET_TIMEOUT" "$CLAUDE" plugin list --json 2>/dev/null)" || return 1
  printf '%s' "$out" | jq -r '.[].id' | sort
}

# Already registered? Re-adding is not harmless: `claude plugin marketplace add`
# records the directory it is handed in settings.json, which is tracked here, so a
# redundant add dirties the repo with a machine-specific absolute path.
marketplace_known() {
  timeout -k "$KILL_GRACE" "$NET_TIMEOUT" "$CLAUDE" plugin marketplace list --json 2>/dev/null \
    | jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null 2>&1
}

# `claude plugin marketplace add <dir>` writes
# extraKnownMarketplaces.<name>.source.path into settings.json -- an absolute,
# machine-specific path in a tracked file. The registration that actually matters
# lives in ~/.claude/plugins/known_marketplaces.json, which is machine state and
# untracked, so drop the settings.json copy again.
#
# Writing this file at all is the last resort (marketplace_known above normally
# keeps `add` from running), so the rewrite is atomic -- temp file in the same
# directory, then rename -- and is refused unless the result is exactly the same
# document minus that one key.
scrub_extra_known_marketplaces() {
  jq -e 'has("extraKnownMarketplaces")' "$SETTINGS_FILE" >/dev/null 2>&1 || return 0

  local tmp
  tmp="$(mktemp -- "$SETTINGS_FILE.XXXXXX")"
  if ! jq --indent 2 'del(.extraKnownMarketplaces)' "$SETTINGS_FILE" >"$tmp"; then
    rm -f -- "$tmp"
    warn "could not strip extraKnownMarketplaces from $SETTINGS_FILE; left it untouched"
    return 0
  fi
  if ! jq -e -s '.[0] == (.[1] | del(.extraKnownMarketplaces))' "$tmp" "$SETTINGS_FILE" >/dev/null; then
    rm -f -- "$tmp"
    warn "refusing to rewrite $SETTINGS_FILE: the scrubbed copy differs by more than extraKnownMarketplaces"
    return 0
  fi
  chmod --reference="$SETTINGS_FILE" -- "$tmp" 2>/dev/null || true
  mv -- "$tmp" "$SETTINGS_FILE"
  info "Dropped the machine-specific extraKnownMarketplaces entry claude wrote into $SETTINGS_FILE"
}

ensure_marketplace() {
  if marketplace_known "$1"; then
    info "Marketplace already registered: $1"
    return 0
  fi
  case "$1" in
    local)
      if [[ ! -d "$MARKETPLACE_PATH" ]]; then
        warn "local marketplace directory not found: $MARKETPLACE_PATH"
        return 0
      fi
      info "Adding local marketplace from: $MARKETPLACE_PATH"
      try plugin marketplace add "$MARKETPLACE_PATH"
      ;;
    claude-plugins-official)
      info "Adding official marketplace: $OFFICIAL_MARKETPLACE"
      try plugin marketplace add "$OFFICIAL_MARKETPLACE"
      ;;
  esac
  scrub_extra_known_marketplaces
}

# Register remote MCP servers (idempotent at user scope)
setup_mcp() {
  if timed_out; then return 0; fi

  if timeout -k "$KILL_GRACE" "$NET_TIMEOUT" "$CLAUDE" mcp get context7 >/dev/null 2>&1; then
    return 0
  fi

  info "Adding remote MCP server: context7 ($CONTEXT7_MCP_URL)"
  if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
    try mcp add --transport http --scope user context7 "$CONTEXT7_MCP_URL" \
      --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}"
  else
    try mcp add --transport http --scope user context7 "$CONTEXT7_MCP_URL"
  fi
}

remove_mcp() {
  info "Removing remote MCP server: context7"
  try mcp remove context7
}

# Install every enabled plugin that is not installed yet, and only those.
install() {
  check_prereqs

  local foreign
  foreign="$(foreign_plugins)"
  if [[ -n "$foreign" ]]; then
    info "Skipping plugins from marketplaces managed elsewhere: $(echo "$foreign" | tr '\n' ' ')"
  fi

  local installed
  if ! installed="$(installed_plugins)"; then
    warn "could not list installed plugins; skipping plugin installation this run"
    setup_mcp
    return 0
  fi

  local missing=() id
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    printf '%s\n' "$installed" | grep -qxF "$id" || missing+=("$id")
  done < <(declared_plugins enabled)

  if [[ ${#missing[@]} -eq 0 ]]; then
    info "All enabled plugins are already installed."
  else
    # Only register a marketplace when something still has to be fetched from it.
    local mkt
    for mkt in "${DECLARED_MARKETPLACES[@]}"; do
      if printf '%s\n' "${missing[@]}" | grep -q "@$mkt\$"; then
        ensure_marketplace "$mkt"
      fi
    done

    for id in "${missing[@]}"; do
      if timed_out; then break; fi
      info "Installing plugin: $id"
      try plugin install "$id" --scope user
    done
  fi

  setup_mcp
}

# Refresh the marketplace sources, then install whatever is still missing. This
# deliberately does NOT uninstall and reinstall: that tore down working plugins
# and the context7 MCP server on every single home-manager switch.
update() {
  check_prereqs

  local mkt
  for mkt in "${DECLARED_MARKETPLACES[@]}"; do
    if timed_out; then break; fi
    info "Updating marketplace: $mkt"
    try plugin marketplace update "$mkt"
  done

  install
}

uninstall() {
  check_prereqs

  local id
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if timed_out; then break; fi
    info "Removing plugin: $id"
    try plugin uninstall "$id" --scope user
  done < <(declared_plugins)

  local mkt
  for mkt in "${DECLARED_MARKETPLACES[@]}"; do
    if timed_out; then break; fi
    info "Removing marketplace: $mkt"
    try plugin marketplace remove "$mkt"
  done
  scrub_extra_known_marketplaces

  remove_mcp

  echo ""
  info "Done! Marketplaces and plugins removed."
}

case "${1:-}" in
  --uninstall)
    uninstall
    ;;
  --update)
    update
    ;;
  --help|-h)
    echo "Usage: $(basename "$0") [--update|--uninstall|--help]"
    echo ""
    echo "  (no args)     Add marketplaces and install the plugins enabledPlugins turns on"
    echo "  --update      Refresh marketplace sources first, then install what is missing"
    echo "  --uninstall   Remove those plugins, the marketplaces and the MCP servers"
    ;;
  *)
    install
    ;;
esac
