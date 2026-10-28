# Runs the installer or the uninstaller silently and waits for it, failing with its log.
param([string]$Installer, [switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$log = Join-Path $env:RUNNER_TEMP "xattot-$(Get-Date -Format HHmmss).log"
$silent = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$log`"")

if ($Uninstall) {
    $uninstaller = "$env:ProgramFiles\Xattot\unins000.exe"
    $process = Start-Process $uninstaller -ArgumentList $silent -Wait -PassThru
    # unins000.exe hands off to a copy of itself in TEMP and returns at once; wait for that copy.
    $deadline = (Get-Date).AddMinutes(2)
    while ((Test-Path $uninstaller) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
} else {
    $process = Start-Process $Installer -ArgumentList $silent -Wait -PassThru
}

Get-Content $log -ErrorAction SilentlyContinue | Select-Object -Last 40
if ($process.ExitCode -ne 0) { throw "exit code $($process.ExitCode)" }
