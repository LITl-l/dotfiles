//! Plover-style output formatting: dictionary translations in, rendered text out.
//!
//! A pure stage after [`crate::dictionary`]: it interprets the meta atoms of Plover's
//! translation language (`{^}`, `{-|}`, `{.}`, `{&x}`, ...) and keeps the rendered text
//! together with the state the next translation needs. Every change is reported as the
//! minimal [`Output`] delta, so a caller can type it as backspaces plus new text.

/// The keystrokes that turn the previous text into the new one: delete `backspaces`
/// chars (Unicode scalar values) from the end, then type `text`.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Output {
    pub backspaces: usize,
    pub text: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Case {
    Capitalize,
    Lower,
    Upper,
}

/// Where the most recent fragment starts (at its space, if it has one).
#[derive(Debug, Clone, Copy)]
struct Fragment {
    start: usize,
    spaced: bool,
}

#[derive(Debug, Clone)]
struct State {
    text: String,
    attach: bool,
    case: Option<Case>,
    glue: bool,
    last: Option<Fragment>,
}

impl Default for State {
    fn default() -> Self {
        State {
            text: String::new(),
            attach: true,
            case: None,
            glue: false,
            last: None,
        }
    }
}

/// Renders a stream of dictionary translations. Holds the text so far and one
/// snapshot per `apply`, so `undo` restores formatting state as well as text.
#[derive(Debug, Clone, Default)]
pub struct Formatter {
    state: State,
    history: Vec<State>,
}

enum Atom {
    Text(String),
    Meta(String),
}

impl Formatter {
    pub fn new() -> Self {
        Self::default()
    }

    /// Formats one dictionary translation and returns the delta it caused.
    pub fn apply(&mut self, translation: &str) -> Output {
        let before = self.state.text.clone();
        self.history.push(self.state.clone());
        for atom in atoms(translation) {
            match atom {
                Atom::Text(t) => self.write(&t, false),
                Atom::Meta(m) => self.meta(&m),
            }
        }
        delta(&before, &self.state.text)
    }

    /// Reverts the most recent `apply`, text and state; empty when there is none.
    pub fn undo(&mut self) -> Output {
        let Some(previous) = self.history.pop() else {
            return Output::default();
        };
        let before = std::mem::replace(&mut self.state, previous);
        delta(&before.text, &self.state.text)
    }

    /// Everything rendered so far.
    pub fn text(&self) -> &str {
        &self.state.text
    }

    fn meta(&mut self, m: &str) {
        match m {
            "" => self.cancel(),
            "^" | "^^" => self.attach_only(),
            "." | "?" | "!" => {
                self.write(m, true);
                self.state.case = Some(Case::Capitalize);
            }
            "," | ":" | ";" => self.write(m, true),
            "-|" => self.state.case = Some(Case::Capitalize),
            ">" => self.state.case = Some(Case::Lower),
            "<" => self.state.case = Some(Case::Upper),
            "*-|" => self.retro_case(Case::Capitalize),
            "*>" => self.retro_case(Case::Lower),
            "*<" => self.retro_case(Case::Upper),
            "*!" => self.retro_delete_space(),
            "*?" => self.retro_insert_space(),
            _ => {
                if let Some(x) = m.strip_prefix('&').filter(|x| !x.is_empty()) {
                    let glued = self.state.glue;
                    self.write(x, glued);
                    self.state.glue = true;
                } else if m.starts_with('^') || m.ends_with('^') {
                    self.attach_meta(m);
                }
            }
        }
    }

    fn cancel(&mut self) {
        self.state.attach = false;
        self.state.case = None;
        self.state.glue = false;
    }

    /// `{^}`: attach the next fragment; like any fresh atom it drops case and glue.
    fn attach_only(&mut self) {
        self.state.attach = true;
        self.state.case = None;
        self.state.glue = false;
    }

    /// `{^x}`, `{x^}`, `{^x^}` and `{^ ^}`: the inner text is kept verbatim.
    fn attach_meta(&mut self, m: &str) {
        let (inner, begin) = match m.strip_prefix('^') {
            Some(rest) => (rest, true),
            None => (m, false),
        };
        let (inner, end) = match inner.strip_suffix('^') {
            Some(rest) => (rest, true),
            None => (inner, false),
        };
        if inner.is_empty() {
            self.attach_only();
            return;
        }
        self.write(inner, begin);
        self.state.attach = end;
    }

    /// Writes one fragment: a space unless attached, then `t` with the pending case.
    fn write(&mut self, t: &str, attached_by_atom: bool) {
        let attached = self.state.attach || attached_by_atom;
        let start = self.state.text.len();
        if !attached {
            self.state.text.push(' ');
        }
        let cased = match self.state.case.take() {
            Some(case) => apply_case(t, case),
            None => t.to_string(),
        };
        self.state.text.push_str(&cased);
        self.state.last = Some(Fragment {
            start,
            spaced: !attached,
        });
        self.state.attach = false;
        self.state.glue = false;
    }

    /// Rewrites the previous word: the trailing run of non-whitespace chars.
    fn retro_case(&mut self, case: Case) {
        let text = &self.state.text;
        let Some(w) = word_start(text) else {
            return;
        };
        let rewritten = apply_case(&text[w..], case);
        // A fragment that starts inside the word moves with the rewritten prefix.
        if let Some(f) = self.state.last.as_mut() {
            if f.start > w {
                f.start = w + apply_case(&text[w..f.start], case).len();
            }
        }
        self.state.text.truncate(w);
        self.state.text.push_str(&rewritten);
    }

    fn retro_delete_space(&mut self) {
        if let Some(f) = self.state.last.as_mut() {
            if f.spaced {
                self.state.text.remove(f.start);
                f.spaced = false;
            }
        }
    }

    fn retro_insert_space(&mut self) {
        if let Some(f) = self.state.last.as_mut() {
            if !f.spaced {
                self.state.text.insert(f.start, ' ');
                f.spaced = true;
            }
        }
    }
}

/// Folds `apply` over a fresh [`Formatter`] and returns the rendered text.
pub fn format(translations: &[&str]) -> String {
    let mut f = Formatter::new();
    for t in translations {
        f.apply(t);
    }
    f.text().to_string()
}

/// Splits a translation into text and meta atoms. A digits-only translation is glue.
fn atoms(translation: &str) -> Vec<Atom> {
    if !translation.is_empty() && translation.bytes().all(|b| b.is_ascii_digit()) {
        return vec![Atom::Meta(format!("&{translation}"))];
    }
    let mut out = Vec::new();
    let mut text = String::new();
    let mut chars = translation.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '\\' if matches!(chars.peek(), Some('{' | '}')) => {
                text.extend(chars.next());
            }
            '{' => {
                let mut meta = String::new();
                let mut closed = false;
                for m in chars.by_ref() {
                    if m == '}' {
                        closed = true;
                        break;
                    }
                    meta.push(m);
                }
                if closed {
                    push_text(&mut out, &mut text);
                    out.push(Atom::Meta(meta));
                } else {
                    text.push('{');
                    text.push_str(&meta);
                }
            }
            _ => text.push(c),
        }
    }
    push_text(&mut out, &mut text);
    out
}

fn push_text(out: &mut Vec<Atom>, text: &mut String) {
    let t = text.trim_matches(' ');
    if !t.is_empty() {
        out.push(Atom::Text(t.to_string()));
    }
    text.clear();
}

fn apply_case(t: &str, case: Case) -> String {
    let mut chars = t.chars();
    match case {
        Case::Capitalize => match chars.next() {
            Some(c) => c.to_uppercase().chain(chars).collect(),
            None => String::new(),
        },
        Case::Lower => match chars.next() {
            Some(c) => c.to_lowercase().chain(chars).collect(),
            None => String::new(),
        },
        Case::Upper => {
            let end = t.find(' ').unwrap_or(t.len());
            t[..end].to_uppercase() + &t[end..]
        }
    }
}

/// Byte offset of the previous word, or `None` when the text ends without one.
fn word_start(text: &str) -> Option<usize> {
    text.char_indices()
        .rev()
        .take_while(|(_, c)| !c.is_whitespace())
        .last()
        .map(|(i, _)| i)
}

/// The minimal edit from `before` to `after`, counted in chars.
fn delta(before: &str, after: &str) -> Output {
    let common = before
        .chars()
        .zip(after.chars())
        .take_while(|(a, b)| a == b)
        .count();
    Output {
        backspaces: before.chars().count() - common,
        text: after.chars().skip(common).collect(),
    }
}
