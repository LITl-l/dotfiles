# Output.backspaces counts the bytes of the removed text, not its chars.
s/backspaces: before\.chars()\.count() - common,/backspaces: before.len() - common,/
