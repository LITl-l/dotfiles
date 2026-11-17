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
# costs one retry, and the reason text names the shape to write instead, so the retry is
# a single edit away.
#
# WHY NO `Corrected command:` ANY MORE. Both denies used to hand back the original
# command with its status read rewritten into bash's braced array read of the pipeline
# status. Measured under `--permission-mode acceptEdits`: a bare `echo` whose only
# unusual content was that braced array read -- no pipe, no parentheses -- still raised
# a permission prompt, although both `Bash(echo *)` and `Bash(echo)` are allowlisted;
# the same line ran silently in an interactive `auto` session. So the ready-made fix was
# unrunnable in exactly the regime that cannot answer a prompt, and a background worker
# died holding it. The redirect-then-read shape below needs no array read at all, so it
# is the only one offered. Rewriting a pipeline into it cannot be done mechanically --
# it needs a log path and a decision about which stage's status is wanted -- hence fixed
# guidance text rather than a generated command.
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

# fish syntax in bash. Unambiguous: bash spells its own pipeline-status array in
# capitals, so a lowercase $pipestatus is the empty string here, every time.
if printf '%s' "$norm" | grep -qE '\$[{]?pipestatus'; then
  deny "\$pipestatus is fish syntax. The Bash tool runs bash, not your login fish, and bash expands it to the empty string -- 21 commands in this corpus did exactly this and all reported success. Do not translate it into bash's braced array read of the pipeline status either: that shape itself raised a permission prompt under --permission-mode acceptEdits and stalled a background worker, even in a bare echo. Drop the pipe instead -- redirect, then read the status on the next line: '<cmd> > <logfile> 2>&1' then 'echo \$?' -- and inspect <logfile> with grep or tail in a separate command."
fi

# `$?` read after a pipeline: that is the LAST stage's status.
if printf '%s' "$norm" | grep -qE '\|.*;.*\$\?'; then
  deny "\$? after a pipeline is the exit status of the LAST stage (tail/head/wc succeed on anything), not of the command you meant to check. This exact shape reported EXIT=0 while home-manager switch had failed its build, and the failure went unnoticed for 24 days. Do not reach for bash's braced array read of the pipeline status: that shape itself raised a permission prompt under --permission-mode acceptEdits and stalled a background worker, even in a bare echo. Drop the pipe instead -- redirect, then read the status on the next line: '<cmd> > <logfile> 2>&1' then 'echo \$?' -- and inspect <logfile> with grep or tail in a separate command."
fi

# Default: silent, defer to the permission rules.
exit 0
