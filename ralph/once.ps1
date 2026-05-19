# ralph/once.ps1 — run one AFK iteration from PowerShell
# Prerequisites: gh CLI (winget install GitHub.cli), gdtoolkit (pip install gdtoolkit)

$commits = git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>$null
$issues  = gh issue list --repo stanhasmusic/ocelot --label ready-for-agent --json number,title,body 2>$null
$prompt  = Get-Content "$PSScriptRoot\prompt.md" -Raw

claude --permission-mode acceptEdits "Previous commits: $commits`n`nIssues: $issues`n`n$prompt"
