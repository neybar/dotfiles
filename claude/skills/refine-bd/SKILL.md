---
description: Refine a Beads issue or epic so it is the right approach, fits the codebase, and is detailed enough for an AI agent to implement later. Takes an optional issue id; defaults to the most recently created issue or epic.
argument-hint: "[issue-id]"
allowed-tools: Read, Grep, Glob, Bash(bd *), Bash(git log*), Bash(git show*), Bash(ls *)
---

# Refine a Beads issue or epic

Refine this bd issue or epic: verify it is the best way to implement the work and that it
integrates well with the codebase. Make sure each task has all the detail an AI coding agent needs
to implement it properly later. If anything is too complex or too large, split it into smaller
issues. Make sure the dependencies between tasks (inside the tree and to other issues) make sense.

Planning only: change issues, not code. Follow the repo's Beads rules first (AGENTS.md, CLAUDE.md,
`bd prime`): server/env settings, `--actor`, and anything it forbids. Never use `bd edit` (it opens
an editor and blocks).

## 1. Pick the target

- If `$ARGUMENTS` names an issue id, use it.
- Otherwise take the newest issue: `bd list --sort created --limit 1 --brief --json` (newest first).
  If it has a `parent`, walk up with `bd show <parent> --json` until there is none, so a freshly
  created epic is refined as a whole rather than its last child.
- Say which id you picked and why before changing anything.

## 2. Load the whole picture

- `bd show <id>` (description, design, notes, comments), then every descendant:
  `bd list --parent <id> --all --json`, recursively, and `bd show` each.
- Dependencies: `bd dep list <id>` for each issue, `bd dep tree <id>`, and `bd dep cycles`.
- Related open work: `bd list --status=open` and `bd search <keywords>`, to find overlap,
  duplicates or issues this should depend on or block.

## 3. Verify against the code

For every issue, check its claims in the repo, not from memory:

- Named files, functions, line numbers, config keys and tests exist and do what the issue says.
  Fix stale references (line numbers drift).
- The approach fits existing patterns (read the repo's agent docs, architecture and design docs,
  and any "don't break" rules). Prefer extending what exists over parallel mechanisms.
- Look for a simpler or more robust approach. If one is clearly better, change the issue and say
  why in its notes. If it is a real trade-off or a product decision, don't pick silently: list it
  for the user (step 7).
- Missing pieces: error and fallback paths, performance on the target hardware, tests (unit vs
  E2E), docs, config tunables, cleanup/teardown.

## 4. Make every task implementable cold

An agent picking up one issue later, with no conversation history, must be able to finish it.
Each task's description should cover:

- **Why**: the problem, with the current behavior and where it lives (`file:line`/function).
- **What**: concrete changes: files, functions, new names, config keys with defaults, interfaces
  between this issue and its neighbors.
- **Decisions already made** (and alternatives rejected), so they aren't re-litigated.
- **Tests**: which suite, which file, what to assert.
- **Done when**: checkable acceptance criteria.

Update with `bd update <id> --description=... / --design=... / --notes=...`. When rewriting a long
description, fetch it with `bd show <id> --json`, edit the text, and write it back whole, so nothing
is lost.

## 5. Right-size and wire up

- Split any issue that is more than roughly one focused PR, mixes unrelated concerns, or has
  parts that could start earlier than the rest: `bd create --parent=<id> ...` with the same level
  of detail. Use `--type=epic` for the target if it has grown children.
- Merge or close duplicates (with a reason pointing at the survivor).
- Dependencies: each edge should mean "can't start or finish without". Add missing ones
  (`bd dep add <issue> <depends-on>`), remove ones that only block needlessly
  (`bd dep remove`), keep cross-tree edges to the specific child that needs them rather than the
  epic (a blocked parent blocks all its children in `bd ready`), and confirm no cycles.
- Check `bd ready` afterward: the first workable issues should be ready.

## 6. Tag model and effort

Tag every implementable issue (not epics) with the cheapest model and thinking effort that can
finish it cold from its description, so later work doesn't burn tokens on an oversized model. A
well-specified issue needs less model: refine first, then tag.

| Model | Use for |
|---|---|
| `haiku` | Mechanical, fully specified: docs, config keys, renames, wiring an existing pattern, simple tests |
| `sonnet` | Most well-specified features and bugs in one area; standard unit/E2E tests |
| `opus` | Cross-cutting or subtle work: async/timing/animation/state lifecycles, performance on constrained hardware, design judgment, bugs whose cause isn't known yet |

| Effort | Use for |
|---|---|
| `low` | Straight-line edits; the description says exactly what to change |
| `medium` | Some reading and choices within a clear plan (the default) |
| `high` | Many interacting parts, tricky invariants, or a "verify first" investigation |
| `xhigh` | Rare: hard algorithms or concurrency where mistakes are subtle and costly |

Never tag `max`; that is the user's call. If the repo or user names other model ids, use those.

- Apply as labels, replacing any old ones:
  `bd update <id> --remove-label model:<old> --remove-label effort:<old> --add-label model:<m> --add-label effort:<e>`
  (check current labels with `bd label list <id>`).
- If an issue only rates `opus`/`high` because it is vague or large, fix that first (step 4 or 5);
  the tag should reflect inherent difficulty, not missing detail.

## 7. Report

Finish with a short summary:

- the target, and the final tree (id, title, depends on, model/effort)
- what changed and why (approach changes, splits, merges, dependency edits, stale references fixed)
- open questions that need the user's decision; leave those issues as they were or mark the
  question in their notes
