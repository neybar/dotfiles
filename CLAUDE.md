# CLAUDE.md

@AGENTS.md

<!-- bd-doctor-divergence: ok -->

## Claude Code only

- Use `bd remember`, not Claude Code's auto-memory or a MEMORY.md file, for persistent project notes (AGENTS.md "Beads in this repo").
- The SessionStart hook in `.claude/settings.json` already runs `bd prime`.
- Shared project hooks and permissions go in `.claude/settings.json`. Per-user permissions go in `.claude/settings.local.json` (git-ignored via the repo `.gitignore`; never commit it). Not to be confused with `claude/`, the source for `~/.claude` (see AGENTS.md).
