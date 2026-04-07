#!/bin/bash

# Stop hook: catches ownership-dodging and session-quitting phrases that
# indicate lazy or avoidant behavior. When triggered, blocks the assistant
# from stopping and forces it to continue working.
#
# Based on benvanik's stop-phrase-guard.sh
# https://gist.github.com/benvanik/ee00bd1b6c9154d6545c63e06a317080

set -euo pipefail

INPUT=$(cat)

# Prevent infinite loops: if the hook already fired once this turn, let
# the assistant stop.
HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [[ "$HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

if [[ -z "$MESSAGE" ]]; then
  exit 0
fi

# Each violation: "grep_pattern|correction_rule"
# Patterns are checked case-insensitively against the full assistant message.
# Ordered by severity — first match wins.

VIOLATIONS=(
  # Ownership dodging
  "pre-existing|NOTHING IS PRE-EXISTING. All builds and tests are green upstream. If something fails, YOUR work caused it. Investigate and fix it."
  "not from my changes|NOTHING IS PRE-EXISTING. You own every change. Investigate the failure."
  "not my change|NOTHING IS PRE-EXISTING. You own every change. Investigate the failure."
  "not caused by my|NOTHING IS PRE-EXISTING. You own every change. Investigate the failure."
  "not introduced by my|NOTHING IS PRE-EXISTING. You own every change. Investigate the failure."
  "already existed before|NOTHING IS PRE-EXISTING. If you found it broken, fix it or explain exactly what is wrong."
  "before my changes|NOTHING IS PRE-EXISTING. There is no 'before your changes' — you own the codebase as it is now."
  "unrelated to my changes|NOTHING IS PRE-EXISTING. If it is broken, fix it."
  "existing bug|NOTHING IS PRE-EXISTING. Investigate and fix."

  # Known limitation dodging
  "known limitation|NO KNOWN LIMITATIONS. Investigate whether it is fixable. Fix it or explain the specific technical reason it cannot be fixed."
  "known issue|NO KNOWN LIMITATIONS. Explain the specific technical reason or fix it."
  "future work|NO KNOWN LIMITATIONS. Fix it now or describe exactly what the fix requires."
  "left as an exercise|NO KNOWN LIMITATIONS. Do the work."

  # Session-length quitting
  "good place to stop|Is the task done? If not, continue working. Sessions are unlimited."
  "good stopping point|Is the task done? If not, continue working. Sessions are unlimited."
  "natural stopping|Is the task done? If not, continue working."
  "logical stopping|Is the task done? If not, continue working."
  "continue in a new session|Sessions are unlimited. There is no reason to defer. Continue."
  "session has gotten long|Sessions are unlimited. Continue working."
  "session has been long|Sessions are unlimited. Continue working."
  "getting long|Sessions are unlimited. Continue working."

  # Permission-seeking mid-task
  "should I continue|Do not ask. If the task is not done, continue. The user will interrupt if they want you to stop."
  "shall I continue|Do not ask. Continue working until the task is complete."
  "shall I proceed|Do not ask. Proceed."
  "would you like me to continue|Do not ask. Continue."
  "would you like to continue|Do not ask. Continue."
  "want me to keep going|Do not ask. Keep going."
  "want me to continue|Do not ask. Continue."
  "should I keep going|Do not ask. Keep going."
  "pick this up later|There is no 'later.' Continue working now."
  "come back to this|There is no 'coming back.' Continue working now."
  "pause here|Do not pause. The task is not done. Continue."
  "stop here for now|Do not stop. The task is not done. Continue."
  "wrap up for now|Do not wrap up. The task is not done. Continue."
  "call it here|Do not stop. Continue working."
)

for entry in "${VIOLATIONS[@]}"; do
  pattern="${entry%%|*}"
  correction="${entry#*|}"

  if echo "$MESSAGE" | grep -iq "$pattern"; then
    jq -n --arg reason "STOP HOOK VIOLATION: $correction" '{
      decision: "block",
      reason: $reason
    }'
    exit 0
  fi
done

exit 0
