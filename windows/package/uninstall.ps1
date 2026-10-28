# Removes the Özbekça Tugmali (Xattot) layout from the user's languages, the registry and System32.
param([switch]$Machine)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Uninstall-Machine {
    $klid = Get-XattotKlid
    if ($klid) { Remove-Item (Join-Path $LayoutsKey $klid) -Recurse }
    foreach ($dir in $LayoutDirs.Keys) { Remove-InUse (Join-Path $dir $Dll) }
}

function Uninstall-User {
    $klid = Get-XattotKlid
    if (-not $klid) { return }
    $tip = Get-XattotTip $klid
    $list = Get-WinUserLanguageList
    foreach ($language in @($list | Where-Object { $_.InputMethodTips -contains $tip })) {
        [void]$language.InputMethodTips.Remove(($language.InputMethodTips | Where-Object { $_ -eq $tip }))
        # Windows refills a language left without a keyboard with its default one, so drop it instead.
        if ($language.InputMethodTips.Count -eq 0) { [void]$list.Remove($language) }
    }
    Set-WinUserLanguageList $list -Force
}

if ($Machine) {
    Uninstall-Machine
    return
}
Uninstall-User
Invoke-MachineStep $PSCommandPath
Write-Host "$LayoutText öçirildi."
