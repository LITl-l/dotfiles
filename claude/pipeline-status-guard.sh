#!/bin/bash
# PreToolUse hook (matcher: Bash): DENY a command whose exit status a pipe has
# already thrown away.
#
# Measured in this corpus: `cmd | tail -N; echo "EXIT=$?"` reported EXIT=0 while the
# `home-manager switch` it wrapped had failed its build -- `$?` there is the status of
# `tail`, which succeeds on anything it is handed. home-manager went on to produce no
# new generation for 24 days without anyone noticing. Separately, 21 Bash commands read
# fish's lowercase `$pipestatus` / `$pipestatus[1]`; bash has no such variable and
# expands it to the empty string, so all 21 reported success and the real status of the
# pipeline was discarded silently.
#
# DENY, not ask. A background worker cannot answer an `ask` at all, and asking is not a
# cheap default here -- approval waiting already measures 148h in this corpus. A deny
# costs one retry, and the reason text carries the corrected command so the retry is a
# single edit away.
#
# PREDICATE NOTE -- what this deliberately does NOT catch. A false deny blocks a correct
# command, so the predicate under-fires on purpose:
#   * `cmd | tail && echo $?` and `... || echo $?`. Only `;` and newline are treated as
#     the sequence separator; `||` is rewritten to a space before matching so that the
#     `|` characters in it can neither look like a pipeline nor like a separator.
#   * a `$?` read in a LATER Bash call -- the hook sees one command at a time.
#   * a `$?` that appears only BEFORE the first pipe (`echo $?; a | b`), which reads the
#     previous command's status and is correct.
#   * `$status` is NOT matched. Unlike `$pipestatus` it is a plausible ordinary bash
#     variable name, so matching it would deny correct commands.
# Single-quoted spans are stripped before matching, so `grep -E 'a|b' f; echo $?` (a `|`
# that is not a pipeline) and `echo 'set -l s $pipestatus' > f.fish` stay silent. A `|`
# inside DOUBLE quotes is still read as a pipeline: the canonical fire, `echo "EXIT=$?"`,
# lives in double quotes, so those cannot be stripped as well. `grep -E "a|b" f; echo $?`
# is therefore the known over-fire -- rewrite it with single quotes.

set -u

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# A newline separates commands exactly as `;` does, so collapsing it keeps a multi-line
# command on the same single-line predicate; single-quoted spans expand to nothing and
# are dropped; `||` is a separator, not a pipe.
norm=$(printf '%s' "$cmd" | tr '\n' ';' | sed "s/'[^']*'//g" | sed 's/||/ /g')

# fish syntax in bash. Unambiguous: bash's variable is uppercase PIPESTATUS, so a
# lowercase $pipestatus is the empty string here, every time.
if printf '%s' "$norm" | grep -qE '\$[{]?pipestatus'; then
  fixed=$cmd
  # fish arrays are 1-based and bash's PIPESTATUS is 0-based, so the index moves too.
  for i in 9 8 7 6 5 4 3 2 1; do
    fixed=$(printf '%s' "$fixed" \
      | sed -E 's/\$[{]?pipestatus\['"$i"'\][}]?/${PIPESTATUS['"$((i - 1))"']}/g')
  done
  fixed=$(printf '%s' "$fixed" | sed -E 's/\$[{]?pipestatus[}]?/${PIPESTATUS[0]}/g')
  deny "\$pipestatus is fish syntax. The Bash tool runs bash, not your login fish, and bash expands it to the empty string -- 21 commands in this corpus did exactly this and all reported success. Use bash's \${PIPESTATUS[0]} (bash indexes from 0, fish from 1, so \$pipestatus[1] becomes \${PIPESTATUS[0]}). Corrected command: $fixed"
fi

# `$?` read after a pipeline: that is the LAST stage's status.
if printf '%s' "$norm" | grep -qE '\|.*;.*\$\?'; then
  # Rewrite only the `$?` that follow the last pipe; one before it is a different,
  # correct read.
  before=${cmd%|*}
  after=${cmd##*|}
  fixed="$before|$(printf '%s' "$after" | sed 's/\$?/${PIPESTATUS[0]}/g')"
  deny "\$? after a pipeline is the exit status of the LAST stage (tail/head/wc succeed on anything), not of the command you meant to check. This exact shape reported EXIT=0 while home-manager switch had failed its build, and the failure went unnoticed for 24 days. Use \${PIPESTATUS[0]}, or drop the pipe and redirect instead (cmd >/tmp/out 2>&1; echo \$?; tail -30 /tmp/out). Corrected command: $fixed"
fi

# Default: silent, defer to the permission rules.
exit 0
