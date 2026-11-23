"""Drive Plover's own formatter headless over gen/inputs.json; print its verdicts as JSON.

Usage (authoring time only, never during a bench run):
  nix shell --impure --expr '<python3.withPackages (ps: [ps.plover])>' \
    --command python -I plover_goldens.py inputs.json > plover.json

Plover is configured as SPEC.md states: start_attached=True, start_capitalized=False,
spaces before words. Each case's translations are fed one at a time through
Formatter.format(undo, do, prev), exactly as Plover's translator feeds it; an undo op
re-formats the last translation as undone. The fake output records Plover's own
backspace/string stream, so each op yields the net (backspaces, text) Plover typed.

Output: {name: {"text": str, "outputs": [[backspaces, text], ...]}} with "error" instead
when Plover raised.
"""

import json
import sys

import plover
from plover import system
from plover.formatting import Formatter
from plover.registry import registry
from plover.translation import Translation

# Plover's metas ({^}, {-|}, {.}, {&x}, retro case, ...) are entry-point plugins; without
# this every meta raises KeyError (the first hand-check run caught exactly that).
registry.update()

# SPEC.md leaves orthography out ("make" + "{^ing}" = "makeing"). With no rules, no
# aliases and no word list, plover.orthography.add_suffix falls through to a plain join.
system.ORTHOGRAPHY_RULES = []
system.ORTHOGRAPHY_RULES_ALIASES = {}
system.ORTHOGRAPHY_WORDS = {}


class Unjudgeable(Exception):
    """Plover has no formatter-level meaning for this input."""


class Recorder:
    """A Plover output that keeps the typed text and the stream of edits."""

    def __init__(self):
        self.text = ""
        self.events = []

    def send_backspaces(self, n):
        self.text = self.text[: len(self.text) - n] if n else self.text
        self.events.append(("bs", n))

    def send_string(self, s):
        self.text += s
        self.events.append(("str", s))

    def send_key_combination(self, combo):
        pass

    def send_engine_command(self, command):
        pass


def net(events):
    """Collapse one op's events to (backspaces, text) as typed at the end of the text."""
    bs, typed = 0, ""
    for kind, v in events:
        if kind == "bs":
            drop = min(v, len(typed))
            typed = typed[: len(typed) - drop]
            bs += v - drop
        else:
            typed += v
    return [bs, typed]


def run(ops):
    out = Recorder()
    f = Formatter()
    f.set_output(out)
    f.start_attached = True
    f.start_capitalized = False
    f.set_space_placement("Before Output")
    trans = []  # Plover's translation list, as its translator would hold it
    stack = []  # one entry per apply, so an undo reverts exactly one apply
    outputs = []
    for op in ops:
        mark = len(out.events)
        if "apply" in op and op["apply"] == "{*?}":
            # Plover's {*?} (macro retro_insert_space) splits the last multi-stroke
            # translation back into its strokes; this formatter has no strokes.
            raise Unjudgeable("{*?} is a stroke-level macro in Plover")
        if "apply" in op and op["apply"] == "{*!}":
            # Plover's {*!} is the translator macro retro_delete_space (macro/retro.py):
            # with two translations, the last not itself a retro command, both are
            # replaced by one translation joining their english with {^~|^}.
            if len(trans) >= 2 and not getattr(trans[-1], "retro", False):
                replaced = trans[-2:]
                merged = Translation([], "{^~|^}".join(t.english for t in replaced))
                merged.retro = True
                f.format(replaced, [merged], trans[:-2])
                trans = trans[:-2] + [merged]
                stack.append(("merge", merged, replaced))
            else:
                stack.append(("noop",))
        elif "apply" in op:
            t = Translation([], op["apply"])
            f.format([], [t], list(trans))
            trans.append(t)
            stack.append(("t", t))
        elif stack:
            entry = stack.pop()
            if entry[0] == "t":
                trans.pop()
                f.format([entry[1]], [], list(trans))
            elif entry[0] == "merge":
                trans.pop()
                f.format([entry[1]], entry[2], list(trans))
                trans.extend(entry[2])
        outputs.append(net(out.events[mark:]))
    return {"text": out.text, "outputs": outputs}


def main():
    with open(sys.argv[1], encoding="utf-8") as fh:
        cases = json.load(fh)
    result = {"_plover_version": plover.__version__}
    for c in cases:
        ops = c.get("ops") or [{"apply": t} for t in c["input"]]
        try:
            result[c["name"]] = run(ops)
        except Exception as e:  # recorded, never fatal: the case is then dropped
            result[c["name"]] = {"error": f"{type(e).__name__}: {e}"}
    json.dump(result, sys.stdout, ensure_ascii=False, indent=1, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
