# ralph/once.ps1 — run one AFK iteration from PowerShell
# Prerequisites: gh CLI (winget install GitHub.cli), gdtoolkit (pip install gdtoolkit)

$commits = git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>$null
$issues  = gh issue list --repo stanhasmusic/ocelot --label ready-for-agent --json number,title,body 2>$null
$prompt  = Get-Content "$PSScriptRoot\prompt.md" -Raw

$fullPrompt = "Previous commits: $commits`n`nIssues: $issues`n`n$prompt"
$fullPrompt | claude --permission-mode bypassPermissions --model claude-opus-4-8 -p --output-format stream-json --verbose |
    ForEach-Object {
        try {
            $obj = $_ | ConvertFrom-Json -ErrorAction Stop
            $text = $obj.message.content | Where-Object { $_.type -eq "text" } | Select-Object -ExpandProperty text -ErrorAction SilentlyContinue
            if ($text) { Write-Host $text -NoNewline }
        } catch { }
    }
