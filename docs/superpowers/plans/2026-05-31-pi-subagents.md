# Pi Subagents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pi extension that lets the main pi session run hidden same-provider, read-only subagents in parallel and receive consolidated summaries.

**Architecture:** The extension registers a `subagent_many` tool. It normalizes domain-specific task requests, creates isolated in-memory pi SDK sessions with recursion disabled, runs them with a concurrency cap, and returns one combined report. Pure helper logic lives in `pi/subagents/core.ts` and is covered by Node tests; pi runtime wiring lives in `pi/subagents/index.ts`.

**Tech Stack:** TypeScript pi extension, pi SDK (`createAgentSession`, `SessionManager`, `DefaultResourceLoader`), Node built-in test runner, Home Manager file deployment.

---

### Task 1: Core helpers

**Files:**
- Create: `pi/subagents/core.test.ts`
- Create: `pi/subagents/core.ts`

- [x] **Step 1: Write failing tests** covering task normalization, native search payload injection, prompt construction, and combined reports.
- [x] **Step 2: Run `node --test pi/subagents/core.test.ts` and verify it fails because `core.ts` does not exist.**
- [x] **Step 3: Implement `core.ts` with pure functions only.**
- [x] **Step 4: Re-run `node --test pi/subagents/core.test.ts` and verify it passes.**

### Task 2: pi extension runtime

**Files:**
- Create: `pi/subagents/index.ts`
- Modify: `modules/pi.nix`

- [x] **Step 1: Register `subagent_many` with a TypeBox input schema.**
- [x] **Step 2: For each normalized task, create an in-memory pi `AgentSession` inheriting cwd/model/modelRegistry/thinking level.**
- [x] **Step 3: Disable extension discovery in child sessions so subagents cannot recursively spawn subagents.**
- [x] **Step 4: Enable only read-only built-in tools: `read`, `grep`, `find`, `ls`.**
- [x] **Step 5: Add a child-session `before_provider_request` hook that calls `applyNativeWebSearch()` only when the task requested web search.**
- [x] **Step 6: Return a consolidated Markdown report and persist the structured report via `pi.appendEntry()`.**

### Task 3: Home Manager integration and verification

**Files:**
- Modify: `modules/pi.nix`

- [x] **Step 1: Deploy `pi/subagents/index.ts` with `@PI_NODE_MODULES@` replaced by the Nix store `node_modules` path.**
- [x] **Step 2: Deploy `pi/subagents/core.ts` next to the extension entrypoint.**
- [x] **Step 3: Run `nixpkgs-fmt modules/pi.nix`.**
- [x] **Step 4: Run `node --test pi/subagents/core.test.ts`.**
- [x] **Step 5: Run `nix flake check`.**
- [x] **Step 6: Run `home-manager switch --flake .#nixos@wsl` after confirming bare `home-manager switch --flake .` is not a valid flake target in this repo.**
