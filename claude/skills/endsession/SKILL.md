---
name: endsession
description: Wrap up a work session. Update the project's documentation with what changed or was learned, save new memories and refine or purge stale ones, and record or ask about any unfinished tasks so the next session can pick up cleanly. Run when James types /endsession.
disable-model-invocation: true
---

# End of session

James runs this before he closes a session. The goal: the next session (yours or another agent's) starts with
everything this one learned, and nothing gets lost or left half-done without a note. Work through the steps below
in order, then give one short report. Keep it proportionate: a quick session may need only a line or two of edits.

## 1. Review the session

Go back over the whole conversation (and any compaction summary) and list for yourself:

- **Facts learned**: names, places, dates, paths, settings, decisions James made.
- **Preferences and corrections**: anything James told you to do differently, or confirmed you did right. These
  matter most; he finds re-teaching annoying.
- **Workflow changes**: new or changed scripts, tools, folder layouts, conventions.
- **Status**: what got finished, what is in progress, what is waiting on him.
- **Loose ends**: promised next steps, unanswered questions, pending approvals, staging or temp files, background
  tasks still running, failed checks.

## 2. Update the documentation

Find where this project keeps its knowledge: `CLAUDE.md`, `AGENTS.md`, `README.md`, notes or log files the session
used, and any file the project instructions point to (some projects say which file is the shared copy for other
agents). Read the relevant parts before editing.

- Put each item from step 1 where a future agent would look for it: the section that covers that topic, a
  status table, a "done" row, an open-items list. Edit existing text rather than appending duplicates, and fix
  anything the session proved wrong.
- Match the file's existing style, terseness and dating (e.g. "(James, 2026-11-02)").
- Keep paired copies in sync when the project asks for it (e.g. an AGENTS.md mirrored in memory).
- Don't create a new doc file unless the project has nowhere suitable; if so, ask first.
- Don't record what git history or the code itself already shows, or chatter that only mattered in this session.

## 3. Save, refine and purge memories

Use the memory system described in your system prompt (its directory, file format, types and the `MEMORY.md`
index). Then:

- **Save** what the session taught that a future session needs and the project docs don't hold: especially
  feedback (with **Why:** and **How to apply:**), facts about James, and pointers to external resources.
- **Refine** existing memories the session changed or sharpened. Update the file in place; don't add a second
  one that half-overlaps.
- **Purge** memories that turned out wrong, are superseded, describe finished one-off work, or are now fully
  recorded in the project docs. Remove their `MEMORY.md` lines too.
- Check every memory that names a file, path, flag or command still matches reality; fix or drop it if not.
- Convert relative dates ("yesterday", "next week") to absolute ones.

## 4. Handle unfinished work

For each loose end from step 1, decide:

- **Clear next step, nothing to decide**: write it in the project's open-items or status section with enough
  context to resume cold (what, where it stands, the exact next command or question, what's waiting on whom).
- **Needs James's call** (keep it, drop it, do it now, which option): ask him. Batch the questions with
  AskUserQuestion (up to 4 per call; give each one enough context to stand alone), then record his answers.
- **Something he asks you to finish now**: do it, then update the docs again.

Don't start destructive, irreversible or outward-facing actions (deleting, publishing, sending, copying to a
server) on the strength of this skill alone; those still need his explicit go-ahead.
Stop any background task you started that is no longer needed, and mention any you leave running.

## 5. Report

Reply briefly:

- Docs updated: file and one line on what changed.
- Memories: added / updated / deleted (by name).
- Open items recorded, and where.
- Anything still waiting on James.

If nothing needed changing in a section, say so in one line rather than skipping it silently.
