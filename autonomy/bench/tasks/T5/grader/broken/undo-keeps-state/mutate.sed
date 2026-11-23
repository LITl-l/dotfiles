# undo restores the text but keeps the formatting state (pending case, attach, glue,
# last fragment) of the apply it reverts.
s/let before = std::mem::replace(&mut self\.state, previous);/let before = std::mem::replace(\&mut self.state.text, previous.text);/
s/delta(&before\.text, &self\.state\.text)/delta(\&before, \&self.state.text)/
