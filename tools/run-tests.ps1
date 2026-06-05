#!/usr/bin/env pwsh
# tools/run-tests.ps1 — run the GUT suite headless (Windows).
# Exit 0 = all tests pass, 1 = a test failed, 2 = no Godot binary found.
# Override the binary with: $env:GODOT = "C:\path\to\godot.exe"; tools\run-tests.ps1
$ErrorActionPreference = "Stop"
$env:GODOT_DISABLE_LEAK_CHECKS = 1

# Resolve a Godot binary: $env:GODOT override -> 'godot' on PATH -> known local install.
$godot = $env:GODOT
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}
if (-not $godot) {
    $fallback = "C:\Users\stanh\Documents\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"
    if (Test-Path $fallback) { $godot = $fallback }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "Godot binary not found. Set `$env:GODOT to the Godot 4.6 exe, or add it to PATH."
    exit 2
}

$root = Split-Path -Parent $PSScriptRoot

# The plain Godot exe is GUI-subsystem on Windows: it won't print to this console,
# so capture stdout/stderr to temp files via Start-Process, then echo them back.
$out = [System.IO.Path]::GetTempFileName()
$err = "$out.err"
$gargs = @(
    "--headless", "--display-driver", "headless", "--audio-driver", "Dummy", "--disable-render-loop",
    "--path", $root, "-s", "res://addons/gut/gut_cmdln.gd", "-gdir=res://test", "-ginclude_subdirs", "-gexit"
)
$p = Start-Process -FilePath $godot -ArgumentList $gargs -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out
$errText = Get-Content $err -ErrorAction SilentlyContinue
if ($errText) { $errText | Write-Host }
Remove-Item $out, $err -ErrorAction SilentlyContinue
exit $p.ExitCode
