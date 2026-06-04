#!/bin/bash
# ralph/once.sh — run one AFK iteration from WSL2
# Prerequisites: gh CLI, gdtoolkit (pip install gdtoolkit), claude CLI in WSL2

commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
issues=$(gh issue list --repo stanhasmusic/ocelot --label ready-for-agent --json number,title,body 2>/dev/null || echo "No issues found")
prompt=$(cat "$(dirname "$0")/prompt.md")

claude --permission-mode acceptEdits \
  --model claude-opus-4-8 \
  "Previous commits: $commits

Issues: $issues

$prompt"
