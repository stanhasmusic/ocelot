#!/bin/bash
# ralph/afk.sh — looping AFK runner (WSL2 + Docker required)
# Prerequisites: Docker Desktop with WSL2 integration, claude CLI inside WSL2
# Usage: bash ralph/afk.sh <iterations>
set -eo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

for ((i=1; i<=$1; i++)); do
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
  issues=$(gh issue list --repo stanhasmusic/ocelot --label ready-for-agent --json number,title,body 2>/dev/null || echo "No issues found")
  prompt=$(cat "$(dirname "$0")/prompt.md")

  docker sandbox run claude . -- \
    --verbose \
    --print \
    --output-format stream-json \
    "Previous commits: $commits

Issues: $issues

$prompt" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
