# A digits-only translation is a plain word, not implicit glue.
s/return vec!\[Atom::Meta(format!("&{translation}"))\];/return vec![Atom::Text(translation.to_string())];/
