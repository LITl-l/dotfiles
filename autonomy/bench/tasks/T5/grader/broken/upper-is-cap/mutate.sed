# {<} only capitalizes the next word, as {-|} does, instead of upper-casing it.
s/"<" => self\.state\.case = Some(Case::Upper),/"<" => self.state.case = Some(Case::Capitalize),/
