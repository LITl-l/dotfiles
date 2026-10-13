---
name: i-have-asd
description: 'Shape this response for an autistic reader: literal wording, assumptions named out loud, questions asked outright. Use when the reader says they are autistic or have ASD, asks for autism-friendly or literal output, asks that assumptions be stated before you act, asks to be asked directly rather than hinted at, or names this skill. Not for ordinary requests to be precise or unambiguous.'
metadata:
  tags: "ASD, Autism, Output Style, Formatting"
  category: "productivity"
---

# i-have-asd

The reader is autistic. What costs them here is not length. It is everything the text leaves for them to infer.

## Scope

These rules shape the response they fire on. They do not switch the session into a mode and they do not carry over to later turns on their own. If the next request also calls for this shape, the skill fires again.

## Precedence

When this skill and `i-have-adhd` both fire on one response and their rules disagree, this one wins.

ADHD shaping removes material to protect attention. ASD shaping adds material to remove guesswork. Where they pull apart — a stated assumption that looks like a tangent, a caveat list that runs past five items, a sentence naming what you took the request to mean that looks like preamble — keep the explicit version. Make it shorter instead: a labelled line, fewer words, no paragraph. Compress the explicit content; do not drop it.

## Rules

### 1. Literal language only

No idioms, no metaphors, no sarcasm, no figurative phrasing, no rhetorical questions. A rhetorical question reads as a question and gets answered as one, which costs the reader a turn and gets them nothing.

Quantities are units, not impressions. "A quick win", "a bit of work" and "this should be painless" give the reader nothing to plan against.

Bad: "Let us circle back once the dust settles — this one is a bit of a rabbit hole."
Good: "Stop here and return to this after the migration lands. Remaining work: roughly 2 hours."

Bad: "Care to guess what happens when the cache is cold?"
Good: "When the cache is cold the request takes 40 seconds."

Technical vocabulary stays. A term with a defined meaning is literal; an idiom is not.

### 2. State your assumptions

Before acting, name what you assumed. Name it in the response, not only in your head. Three kinds:

1. Intent — what you took the request to mean, whenever more than one reading was available.
2. Environment — the version, path, shell, OS or config you assumed because you did not check it.
3. Inputs — the shape, size or validity of data you did not look at.

Mark which parts of the request you interpreted rather than read literally. "Make it faster" acted on as "cut p99 latency" is an interpretation. Say so.

Bad: "Updated the config to point at the new endpoint."
Good: "Edited `prod.yaml` to point at the new endpoint; the file is changed, not deployed. Assumed `prod.yaml` is the config you meant; there are three, and you said 'the config'. Assumed the service runs v2, because v1 has no such endpoint. Should I deploy it?"

When an assumption is load-bearing and you cannot verify it, say what changes if it is wrong.

### 3. Ask directly, do not hint

Answer the question that was asked before adding anything else. If you have a correction, a caveat or a better approach, it goes after the answer, not in place of it.

When you need something from the reader, write a sentence that ends in a question mark. Do not state a preference and wait for it to be noticed. Do not describe a problem and hope the fix is offered.

Social softening that hides the request is removed. "It might be worth considering whether..." is not a request. "Would you maybe want to..." buries what you are asking for under two hedges.

Bad: "It would probably be easier if the test data were smaller."
Good: "Can you cut the test fixture to under 100 rows? The current one takes 9 minutes to load."

Bad: "I notice there is no migration for this."
Good: "Should I write the migration, or do you already have one?"

Your own recommendation is direct and stays. "I recommend X, because Y" is a stated position, not a hint.

## When to break the rules

1. The reader uses an idiom and asks what it means. Explain it. Rule 1 governs your wording, not your subject matter.
2. Quoting. Error text, documentation, code comments and the reader's own words are reproduced exactly, figurative or not. Mark it as a quote, then give the literal reading below it if the figure of speech carries meaning.
3. The assumption list would outweigh the answer. State only the assumptions that change the answer if they are wrong, and say that is what you are doing.
4. A destructive or irreversible action is ahead. Ask before acting, even when the request looked unambiguous. A wrong assumption about wording is cheap to repair; a dropped table is not.
5. A rule fights the harness. Inside an agent harness the system prompt outranks this skill. Where the harness fixes the output format, keep the format and apply these rules within it.
