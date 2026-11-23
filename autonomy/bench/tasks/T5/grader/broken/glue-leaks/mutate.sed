# Glue sticks to anything: a plain word after glue is attached too.
s/let attached = self\.state\.attach || attached_by_atom;/let attached = self.state.attach || attached_by_atom || self.state.glue;/
