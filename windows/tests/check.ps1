# Checks what the installer leaves behind. -Installed: the layout's registry key and DLLs, the input
# method's COM classes and profile, both keyboards in the user's language list and the Settings > Apps
# entry; prints the KLID. -Removed: none of them is left.
param([switch]$Installed, [switch]$Removed)

$ErrorActionPreference = 'Stop'
$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
$app = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E07342C7-7AA5-4D40-8506-28D42FF97026}_is1'

$keys = @(Get-ChildItem $layouts | Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq 'kbduzxt.dll' })
$clsid = '{FD47E00C-1DD3-4169-B402-BE4F14473EEE}'
$imeTip = "0443:${clsid}{59E8B67C-4644-47C6-81CE-C0249DD669FA}"
$classes = @("HKLM:\SOFTWARE\Classes\CLSID\$clsid\InprocServer32", "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID\$clsid\InprocServer32")
$imeProfile = "HKLM:\SOFTWARE\Microsoft\CTF\TIP\$clsid\LanguageProfile\0x00000443\{59E8B67C-4644-47C6-81CE-C0249DD669FA}"
$allTips = @((Get-WinUserLanguageList).InputMethodTips)
$tips = @($allTips | Where-Object { $_ -like '0443:A*' })

if ($Installed) {
    if ($keys.Count -ne 1) { throw "expected one layout key, found $($keys.Count)" }
    $klid = $keys[0].PSChildName
    Get-ItemProperty $keys[0].PSPath | Format-List 'Layout*' | Out-Host
    if ($tips -notcontains "0443:$($klid.ToUpper())") { throw "layout $klid not in the language list: $tips" }
    foreach ($dir in 'System32', 'SysWOW64') {
        if (-not (Test-Path "$env:SystemRoot\$dir\kbduzxt.dll")) { throw "kbduzxt.dll missing from $dir" }
    }
    foreach ($class in $classes) {
        $dll = (Get-ItemProperty $class).'(default)'
        if (-not (Test-Path $dll)) { throw "$class points to a missing $dll" }
        Write-Host "input method: $dll"
    }
    if (-not (Test-Path $imeProfile)) { throw 'the input method profile is not registered' }
    # Piped straight from the cmdlet the list arrives as one object, so filter a stored copy.
    $languages = Get-WinUserLanguageList
    $languages | Format-Table LanguageTag, InputMethodTips -AutoSize | Out-String -Width 300 | Out-Host
    $uzbek = @(($languages | Where-Object { $_.LanguageTag -like 'uz-Latn*' }).InputMethodTips)
    if ($uzbek[0] -ne $imeTip) { throw "the input method is not the first Uzbek keyboard: $uzbek" }
    $entry = Get-ItemProperty $app
    Write-Host "Settings > Apps: $($entry.DisplayName) $($entry.DisplayVersion)"
    $klid
}

if ($Removed) {
    if ($keys.Count -ne 0) { throw 'layout still in the registry' }
    if ($tips.Count -ne 0) { throw "layout still in the language list: $tips" }
    if ($allTips -contains $imeTip) { throw 'input method still in the language list' }
    foreach ($class in $classes) { if (Test-Path $class) { throw "$class still registered" } }
    if (Test-Path $imeProfile) { throw 'input method profile still registered' }
    if (Test-Path $app) { throw 'still listed in Settings > Apps' }
    if (Test-Path "$env:ProgramFiles\Xattot") { throw "$env:ProgramFiles\Xattot still exists" }
}
