use steno_core::{format, Formatter, Output};

fn out(backspaces: usize, text: &str) -> Output {
    Output {
        backspaces,
        text: text.to_string(),
    }
}

/// Applies every translation, replaying each delta on a buffer, and checks the replay
/// against `text()` after every step.
fn replayed(translations: &[&str]) -> String {
    let mut f = Formatter::new();
    let mut buf = String::new();
    for t in translations {
        let o = f.apply(t);
        for _ in 0..o.backspaces {
            buf.pop();
        }
        buf.push_str(&o.text);
        assert_eq!(buf, f.text(), "replay diverged after {t:?}");
    }
    buf
}

#[test]
fn words_go_space_before_and_the_first_is_attached() {
    assert_eq!(format(&["hello", "world"]), "hello world");
    assert_eq!(format(&["hello world", "again"]), "hello world again");
    assert_eq!(format(&[]), "");
}

#[test]
fn attach_forms() {
    assert_eq!(format(&["test", "{^ing}"]), "testing");
    assert_eq!(format(&["{in^}", "side"]), "inside");
    assert_eq!(format(&["a", "{^-^}", "b"]), "a-b");
    assert_eq!(format(&["a", "{^}", "b"]), "ab");
    assert_eq!(format(&["a", "{^^}", "b"]), "ab");
    assert_eq!(format(&["a{^}", "b"]), "ab");
    assert_eq!(format(&["a", "{^}b"]), "ab");
    assert_eq!(format(&["a", "{^ ^}", "b"]), "a b");
    assert_eq!(format(&["make", "{^ing}"]), "makeing");
}

#[test]
fn glue_and_digits() {
    assert_eq!(format(&["{&a}", "{&b}", "{&c}"]), "abc");
    assert_eq!(format(&["{&a}", "word", "{&b}"]), "a word b");
    assert_eq!(format(&["x", "{&a}", "{&b}"]), "x ab");
    assert_eq!(format(&["1", "2", "3"]), "123");
    assert_eq!(format(&["page", "4", "2"]), "page 42");
}

#[test]
fn case_operators() {
    assert_eq!(format(&["{-|}", "hello"]), "Hello");
    assert_eq!(format(&["a", "{-|}", "b"]), "a B");
    assert_eq!(format(&["a", "{<}", "nasa"]), "a NASA");
    assert_eq!(format(&["{<}", "hello world"]), "HELLO world");
    assert_eq!(format(&["{>}", "Word"]), "word");
    assert_eq!(format(&["{-|}", "{>}", "Word"]), "word");
    assert_eq!(format(&["x", "{<}", "{^}", "y"]), "xy");
}

#[test]
fn retro_case_acts_on_the_previous_word_only() {
    assert_eq!(format(&["hello", "{*-|}"]), "Hello");
    assert_eq!(format(&["one", "two", "{*-|}", "three"]), "one Two three");
    assert_eq!(format(&["one", "two", "{*<}"]), "one TWO");
    assert_eq!(format(&["one", "Two", "{*>}"]), "one two");
    assert_eq!(format(&["{*-|}", "x"]), "x");
}

#[test]
fn punctuation() {
    assert_eq!(format(&["hello", "{.}", "world"]), "hello. World");
    assert_eq!(format(&["what", "{?}", "no"]), "what? No");
    assert_eq!(format(&["wow", "{!}", "yes"]), "wow! Yes");
    assert_eq!(format(&["yes", "{,}", "sir"]), "yes, sir");
    assert_eq!(format(&["a", "{:}", "b", "{;}", "c"]), "a: b; c");
}

#[test]
fn retro_spacing() {
    assert_eq!(format(&["hello", "world", "{*!}"]), "helloworld");
    assert_eq!(format(&["in", "{^side}", "{*?}"]), "in side");
    assert_eq!(format(&["in", "{^side}", "{*!}"]), "inside");
}

#[test]
fn cancel_escape_and_unknown_metas() {
    assert_eq!(format(&["a", "{-|}", "{}", "word"]), "a word");
    assert_eq!(format(&["a{^}", "{}", "b"]), "a b");
    assert_eq!(format(&["1", "{}", "2"]), "1 2");
    assert_eq!(format(&["\\{x\\}"]), "{x}");
    assert_eq!(format(&["a", "{#Return}", "b"]), "a b");
    assert_eq!(format(&["a{^}", "{PLOVER:TOGGLE}", "b"]), "ab");
}

#[test]
fn outputs_are_minimal_deltas() {
    let mut f = Formatter::new();
    assert_eq!(f.apply("cat"), out(0, "cat"));
    assert_eq!(f.apply("{*-|}"), out(3, "Cat"));
    assert_eq!(f.apply("{.}"), out(0, "."));
    assert_eq!(f.apply("{-|}"), Output::default());
    assert_eq!(f.text(), "Cat.");
    assert_eq!(replayed(&["a", "b", "{*!}", "{*?}", "{.}", "c"]), "a b. C");
}

#[test]
fn backspaces_count_chars_not_bytes() {
    let mut f = Formatter::new();
    f.apply("日本");
    assert_eq!(f.apply("語"), out(0, " 語"));
    assert_eq!(f.undo(), out(2, ""));
    assert_eq!(f.undo(), out(2, ""));
    assert_eq!(f.text(), "");
    let mut g = Formatter::new();
    g.apply("café");
    g.apply("x");
    assert_eq!(g.apply("{*!}"), out(2, "x"));
}

#[test]
fn undo_restores_text_and_state() {
    let mut f = Formatter::new();
    f.apply("hello");
    f.apply("{.}");
    assert_eq!(f.undo(), out(1, ""));
    assert_eq!(f.apply("world"), out(0, " world"));
    assert_eq!(f.text(), "hello world");

    let mut g = Formatter::new();
    g.apply("a");
    g.apply("{-|}");
    assert_eq!(g.undo(), Output::default());
    assert_eq!(g.apply("b"), out(0, " b"));

    let mut h = Formatter::new();
    assert_eq!(h.undo(), Output::default());
    h.apply("x");
    h.undo();
    assert_eq!(h.apply("y"), out(0, "y"));
    assert_eq!(Formatter::default().text(), "");
}
