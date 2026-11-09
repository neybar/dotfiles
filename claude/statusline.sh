#!/bin/sh
# Claude Code status line. Does nothing (instead of erroring) when node is missing.
command -v npx >/dev/null 2>&1 || exit 0
exec npx -y ccstatusline@latest
