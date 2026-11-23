// Authoring-time harness, never part of a bench run: gen/generate copies it into a
// scratch clone (with the reference installed) as tests/zz_dump.rs and runs it, to get
// the reference's verdict on every gen/inputs.json case in plover_goldens.py's shape.
use serde_json::{json, Map, Value};
use steno_core::{format, Formatter};

#[test]
fn dump() {
    let input = std::env::var("T5_DUMP_IN").expect("T5_DUMP_IN");
    let output = std::env::var("T5_DUMP_OUT").expect("T5_DUMP_OUT");
    let cases: Vec<Value> =
        serde_json::from_str(&std::fs::read_to_string(input).expect("read")).expect("json");
    let mut res = Map::new();
    for c in cases {
        let name = c["name"].as_str().expect("name").to_string();
        let ops: Vec<Value> = match c.get("ops") {
            Some(ops) => ops.as_array().expect("ops").clone(),
            None => c["input"]
                .as_array()
                .expect("input")
                .iter()
                .map(|t| json!({ "apply": t }))
                .collect(),
        };
        let mut f = Formatter::new();
        let mut outputs = Vec::new();
        for op in &ops {
            let o = match op.get("apply") {
                Some(t) => f.apply(t.as_str().expect("apply")),
                None => f.undo(),
            };
            outputs.push(json!([o.backspaces, o.text]));
        }
        if let Some(input) = c.get("input") {
            let ts: Vec<&str> = input
                .as_array()
                .expect("input")
                .iter()
                .map(|t| t.as_str().expect("str"))
                .collect();
            assert_eq!(format(&ts), f.text(), "format() and apply() disagree on {name}");
        }
        res.insert(name, json!({ "text": f.text(), "outputs": outputs }));
    }
    std::fs::write(output, Value::Object(res).to_string()).expect("write");
}
