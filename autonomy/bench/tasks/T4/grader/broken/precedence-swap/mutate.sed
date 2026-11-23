# precedence-swap: account state (NOT_OPEN, CLOSED) is checked before balancing, so an
# unbalanced transaction posting to an unopened account reports NOT_OPEN.
s/^    if (stage_balance(tx) || stage_accounts(tx))$/    if (stage_accounts(tx) || stage_balance(tx))/
