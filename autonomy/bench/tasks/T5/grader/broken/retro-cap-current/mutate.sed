# {*-|} capitalizes the next word, like {-|}, instead of the previous one.
s/"\*-|" => self\.retro_case(Case::Capitalize),/"*-|" => self.state.case = Some(Case::Capitalize),/
