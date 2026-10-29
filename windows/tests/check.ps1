# Checks what the installer leaves behind. -Installed: one registry key, the user's language list,
# both DLLs and the Settings > Apps entry; prints the KLID. -Removed: none of them is left.
param([switch]$Installed, [switch]$Removed)

$ErrorActionPreference = 'Stop'
$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
$app = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E07342C7-7AA5-4D40-8506-28D42FF97026}_is1'

$keys = @(Get-ChildItem $layouts | Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq 'kbduzxt.dll' })
$tips = @((Get-WinUserLanguageList).InputMethodTips | Where-Object { $_ -like '0443:A*' })

if ($Installed) {
    if ($keys.Count -ne 1) { throw "expected one layout key, found $($keys.Count)" }
    $klid = $keys[0].PSChildName
    Get-ItemProperty $keys[0].PSPath | Format-List 'Layout*' | Out-Host
    if ($tips -notcontains "0443:$($klid.ToUpper())") { throw "layout $klid not in the language list: $tips" }
    foreach ($dir in 'System32', 'SysWOW64') {
        if (-not (Test-Path "$env:SystemRoot\$dir\kbduzxt.dll")) { throw "kbduzxt.dll missing from $dir" }
    }
    $entry = Get-ItemProperty $app
    Write-Host "Settings > Apps: $($entry.DisplayName) $($entry.DisplayVersion)"
    $klid
}

if ($Removed) {
    if ($keys.Count -ne 0) { throw 'layout still in the registry' }
    if ($tips.Count -ne 0) { throw "layout still in the language list: $tips" }
    if (Test-Path $app) { throw 'still listed in Settings > Apps' }
    if (Test-Path "$env:ProgramFiles\Xattot") { throw "$env:ProgramFiles\Xattot still exists" }
}
