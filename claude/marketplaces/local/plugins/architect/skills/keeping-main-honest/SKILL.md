---
name: keeping-main-honest
description: Use when deciding what to commit to the default branch — creating, placing, or merging a design doc, plan, spec, requirements, tasks file, or ADR; finishing a feature branch or preparing a PR; ending an agent session whose decisions live only in chat or plan-mode output; or finding a doc on main that no longer matches the code.
---

# Keeping Main Honest

## Core Principle

The default branch holds only artifacts that **cannot silently become a lie**. An artifact earns its place on `main` by passing one of two gates:

- **(a) Self-cleaning** — executable and CI-guarded. If it drifts from the code, CI goes red. Tests, IaC, and acceptance criteria wired to tests cannot quietly diverge from truth.
- **(b) Immutable** — a dated, append-only, post-hoc record that is never rewritten. An ADR records a decision *at the moment it was made* and is only ever superseded, never edited.

Those two gates are how an artifact stays honest *on its own*. A little **deliberately-tended prose** is admitted too: the **steering layer** lands on `main` (it documents *process, not product*, so the code cannot contradict it), and a **spec** may stay **conditionally** — only while someone pays to keep it synced. So `main` has three lanes: **lands** (passed a gate, or is steering), **conditional** (an actively-synced spec), and **branch-only** (everything else).

Everything outside those lanes is a **pre-implementation expectation**. The instant code becomes the source of truth for *how it is built*, the prose that described the plan becomes a second ledger that starts to rot. **A stale doc is worse than no doc** — it actively misleads the reader and the agent who lack the context to know it is stale.

**The cut is not "qualitative vs quantitative," and not "verifiable vs not."** It is **truth-preserving vs rots-as-expectation.** The qualitative intuition is *mostly* right (durable intent over shifting state) but misses in two places: tests/IaC are the *least* qualitative artifacts yet most belong on main; `tasks` are verifiable yet must be discarded.

## When to Use

- Placing or merging a `design.md`, `plan.md`, `tasks.md`, spec, requirements doc, or ADR
- Finishing a feature branch / preparing a PR — deciding what reaches the default branch
- Ending a session whose decisions live only in the chat or plan-mode output
- You find a doc on `main` that no longer matches the code

## The Rubric

| Lands on `main` (truth preserved) | Conditional (only while synced) | Branch-only (distill & discard) |
|---|---|---|
| tests · IaC | Spec / requirements | design (Kiro) |
| executable EARS / Gherkin (wired to BDD) | | plan (SpecKit) |
| ADR (dated, immutable) | | Claude plan-mode output |
| **steering: CLAUDE.md / AGENTS.md** | | tasks · design docs |

EARS/Gherkin **stay on `main` only if they run as tests** (left column). Left as prose, they are **branch-only** (right column).

## The Two Traps

**Trap 1 — "A design doc is a fine durable home for the *why*."**
No. Relocating `design.md` to `docs/design/foo.md` changes nothing: it still has no CI guard and no immutability, so it rots like any pre-implementation prose. The *why* survives **only by transmutation** — distill it into an **ADR** (dated, append-only, supersede-tracked) plus **tests** and **code comments**, then **discard the design doc**. ADR ≠ design doc; they are not interchangeable. The ADR is honest because it is a fixed record of *what was decided*; a design doc is a forecast of *how it will be built*, which the code immediately outdates.

**Trap 2 — "Verifiable means it stays."**
No. `tasks.md` is perfectly checkable yet must be discarded — a checklist is **consumed** the moment its boxes are ticked. Verifiable `tests` stay (CI keeps them honest); verifiable `tasks` go (they have spent their purpose). The line is **durability**, not verifiability.

## The Middle Column Is the Only "Conditional"

Spec / requirements may live on `main` **only while someone actually pays the sync discipline**. Unmaintained, a spec rots like any expectation — change the code by vibe without updating the spec and the two drift apart. Three honest resolutions:

1. **Promote** to a verifiable form (Gherkin/tests) → left column.
2. **Commit** to a living-document sync discipline → keep it, and mean it.
3. **Escape** the durable core into an ADR and discard the body.

Worst option: park it on `main` and pay no maintenance.

## Distill Before Merge

At PR time, extract the nutrients from the scaffold, then fold the scaffold (squash or delete it):

- *Why this shape?* → **ADR**
- *How must it behave?* → **test** (interface/contract facts that aren't behavioral → **code comments** beside the code)
- *Conventions / where things live / what not to touch?* → **steering**

Then squash or delete `plan.md` / `tasks.md` / `design.md`. The durable record of **what & why** is carried by **git history (PR + merge commit) and ADR** — not by doc files on `main`. So folding the scaffold loses nothing.

## Cold-Start Discipline (Why This Matters Most for Agents)

Treat **every session as a cold start** — operators and agents resume with no memory. That is exactly when a stale doc is most dangerous: a reader *with* memory sees an obviously outdated `design.md` and ignores it; a memoryless reader or agent *believes* it and acts on a false premise. Under intermittent agentic work, "no silent lies on main" graduates from hygiene to a rule that decides whether the work succeeds.

Cold start also adds a *positive* requirement — the repo must **boot context**, not just avoid lies:

- **Steering layer** — CLAUDE.md / AGENTS.md / steering: **conventions, how to build and run the tests, where things live, what not to touch**, plus a maintained high-level map. The one prose exception that *belongs* on `main`, because it is intentionally maintained, slow-changing, and about **conventions, not implementation**. Unlike a spec, steering makes **no claim the code can contradict** — it documents *process, not product* — which is why it lands on `main` outright while a spec stays only conditionally. The highest-ROI asset in intermittent work — the handoff doc read first on every cold boot.
- **ADR** is the immutable backbone of *why it is this way* — the only honest source once memory is gone. Design docs cannot play this role.
- **Session-end ritual:** the freshest, richest context — plan-mode output and the chat itself — **dies with the session.** Before ending, land the residue worth keeping into **steering / ADR / test.** Never leave a decision in chat and walk away.
- A half-built branch's `plan.md` / `tasks.md` is the context needed to *resume that branch* — it belongs **on the branch** and must never reach `main`.

## Rationalizations

| Excuse | Reality |
|---|---|
| "design.md captures real *why* — keep it under docs/" | Relocating adds no guard. Transmute to ADR + tests, then discard. |
| "It's verifiable, so it can stay" | tasks are verifiable and still discarded. Durability is the test, not verifiability. |
| "I'll keep the plan for reference" | An unmaintained plan is a second ledger that rots. The code is the reference. |
| "The spec documents the requirements" | Honest only while synced. Promote it, commit to syncing it, or escape its core to an ADR. |
| "The decision is in the PR thread / chat" | Chat dies at session end and is not read on cold start. Land it in an ADR. |
| "Throwing away the design feels wasteful" | The *nutrient* (why → ADR, behavior → test) is kept. Only the scaffold is folded. |

## Red Flags — STOP

- About to commit `plan.md` / `tasks.md` / `design.md` to the default branch
- Relocating a design doc under `docs/` and calling it durable
- A doc on `main` that contradicts the code, left in place
- Ending a session with decisions only in chat or plan-mode output
- Treating "design doc" and "ADR" as interchangeable homes for *why*

**All of these mean: distill the durable core into ADR / test / steering, then fold the scaffold.**

**REQUIRED SUB-SKILL for the ADR step:** Use the `adr-discipline` skill — an ADR must *decide* (or defer with triggers), not enumerate.
