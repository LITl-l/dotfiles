---
name: adr-discipline
description: Use when writing Architecture Decision Records, proposing tech-stack choices, or making tool/library recommendations — enforces verification, cross-decision consistency, and decide-or-defer discipline
---

# ADR Discipline

## Core Principle

An ADR must **decide** or **explicitly defer with trigger conditions**. An ADR that only enumerates options is a survey, not a decision record.

**Violating the letter is violating the spirit:** "I surveyed the options" is not a decision. "We'll pick later" without trigger conditions is not a deferral.

## When to Use

- Writing or editing Architecture Decision Records
- Proposing a tool, library, service, or pattern for adoption
- Evaluating alternatives for a tech-stack area (storage, observability, config, auth, queues, etc.)
- Reviewing architectural proposals — your own or others'

## Anti-patterns

| Anti-pattern | Counter |
|--------------|---------|
| Recommending a tool without checking it's still maintained | Check last release date, open/closed issue ratio, security advisories in the **current session** before mentioning it |
| Accepting brand promises without technical verification | Search the **official forum or issue tracker** for the specific capability. Example: GB10 marketing implies Confidential Computing; the official forum shows it lacks CC |
| Proposing a runtime dep when the user stated "no runtime deps" | Re-read the user's constraints before each recommendation. Validators, ORMs, utility libraries all count |
| Unifying components without questioning whether unification solves the real pain | Name the specific pain the unification eliminates. If you can't, don't unify |
| Adding a new store/service when the existing one could serve | Default question: *can Postgres do this? can the existing queue handle this?* Prove the existing tool is insufficient before adding a new one |
| Writing ADRs that enumerate options without deciding | Decide — or write a **deferred-adoption ADR** with explicit trigger conditions |
| Missing cross-ADR consistency | Re-read prior committed ADRs before writing a new one. Proposing Langfuse right after committing to Postgres-only is a contradiction to catch |
| Narrating internal process inside the ADR body | Let the **commit message** carry the reasoning trail. The ADR records *what was decided* and *why*, not *how you arrived there* |

## Honest Recalibration

When the user supplies course-correcting information, treat it as **primary evidence** and rewrite the affected ADRs. **Do not defend the prior draft.**

Real examples worth internalizing:

- "NIM actually has poor model flexibility in practice" → rewrite, don't defend the NIM recommendation
- "Moon has VCS hooks built-in" → drop the lefthook ADR, it's redundant
- "LiteLLM had a supply-chain attack" → re-evaluate LiteLLM weight against the attack surface
- "just is redundant with Moon scripts" → drop just, don't rationalize keeping both

When course-corrected, the correct move is: acknowledge the new evidence, rewrite the ADR, and let the commit message note what changed.

## Search Discipline

Comparison queries ("X vs Y") systematically under-report failure modes — they surface marketing pages, not postmortems. Broaden deliberately:

- **Raise the abstraction level.** Search the underlying problem, not the assumed tool
- **Check recent papers** (arxiv, OpenReview, within the last year)
- **Negate the default premise.** "without RAG", "Postgres-only", "no Kubernetes", "WASM instead of X"
- **Mix in regional / regulatory context** when relevant (sovereign, on-prem, airgapped, 日本)
- **GitHub trending, filtered** by language × last 3 months × star growth
- **Research-lab OSS** (Anthropic, DeepMind, Apple, AISI, NTT研, 産総研)
- **"Death of X" / "why we stopped using X" postmortems** — withdrawal writeups carry more signal than adoption writeups

## Deferred-adoption Pattern

Not-deciding-yet is often the best decision (examples: WASM, Langfuse, Pkl/CUE — aggressive early adoption has high blast radius). A deferred-adoption ADR must specify:

- **Trigger condition** — the concrete signal that flips the decision (e.g., "when we exceed 10k events/day", "when a second backend language joins the stack", "when the upstream stabilizes a 1.0 release")
- **What state to revisit** — which metric, which team signal, which upstream release
- **The default in the meantime** — what we are doing instead, explicitly

A deferred ADR without a trigger is indistinguishable from procrastination.

## Deliverables Checklist

- [ ] Repo state grounded — what exists, what's dead, what's duplicated
- [ ] Selection principles (R1..Rn) documented in the plan snapshot
- [ ] Polyglot / language assessment if more than one backend language
- [ ] One ADR per major decision area, **blast-radius ordered** (highest impact first)
- [ ] Each ADR names rejected alternatives **with reasons**
- [ ] Deferred-adoption ADRs have explicit trigger conditions
- [ ] Cross-ADR consistency verified — no contradictions between committed ADRs
- [ ] Snapshot saved in a jj workspace; **no PR unless requested**
- [ ] Commit message summarizes what changed in each revision round

## Red Flags — STOP and Re-ground

- "Let me recommend X" without having opened X's repo / forum / changelog in this session
- Proposing a new service or store before asking whether the existing one suffices
- Writing "we should consider A, B, or C..." without resolving to one (or a deferred-adoption note with triggers)
- Explaining in the ADR *how you arrived at the decision* rather than *what was decided and why*
- Feeling the urge to defend a prior draft after the user corrected a factual premise
- Proposing something in ADR #4 that contradicts a commitment in ADR #2

**All of these mean:** stop, re-ground in current evidence, rewrite. The previous draft is not sunk cost — it's a stepping stone to the correct one.

## Why This Skill Is Process-Heavy, Not Output-Template

The value is in the **discovery loop** — catching that NIM's model flexibility is worse than the brand implies, that GB10 lacks CC, that Moon subsumes lefthook, that an "unstructured" dep is actually dead code. An output template would standardize the shape of ADRs but miss the discipline that makes them correct. Templates are cheap; grounded decisions are not.
