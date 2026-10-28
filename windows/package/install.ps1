# Installs the Özbekça Tugmali (Xattot) layout and adds it to the current user's Uzbek language.
param([switch]$Machine)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function New-Klid {
    # Custom layouts take a KLID whose first digit is a-f; the low word names the language.
    foreach ($i in 0..0xfff) {
        $klid = 'a{0:x3}{1}' -f $i, $LanguageId
        if (-not (Test-Path (Join-Path $LayoutsKey $klid))) { return $klid }
    }
    throw 'Bös KLID topilmadi.'
}

function New-LayoutId {
    # Windows tells custom layouts apart by Layout Id, which must be unique among all of them.
    $used = Get-ChildItem $LayoutsKey |
        ForEach-Object { (Get-ItemProperty $_.PSPath).'Layout Id' } |
        Where-Object { $_ } |
        ForEach-Object { [Convert]::ToInt32($_, 16) }
    # Measure-Object returns a double, which the x4 format rejects.
    $highest = [int]($used | Measure-Object -Maximum).Maximum
    '{0:x4}' -f ([Math]::Max(0xc0, $highest + 1))
}

function Install-Machine {
    $native = Get-NativeArchitecture
    if (-not $native -or -not [Environment]::Is64BitProcess) {
        throw 'Xattot 64-bit Windows (x64 yoki ARM64) talab qiladi.'
    }
    foreach ($dir in $LayoutDirs.Keys) {
        $build = if ($LayoutDirs[$dir] -eq 'native') { $native } else { 'wow64' }
        $dest = Join-Path $dir $Dll
        Remove-InUse $dest
        Copy-Item (Join-Path $PSScriptRoot "$build\$Dll") $dest
    }

    $klid = Get-XattotKlid
    if (-not $klid) {
        $klid = New-Klid
        $layoutId = New-LayoutId
        # Layout File goes in first, so a rerun after any later failure finds this key again.
        $created = New-Item (Join-Path $LayoutsKey $klid)
        New-ItemProperty $created.PSPath 'Layout File' -Value $Dll | Out-Null
        New-ItemProperty $created.PSPath 'Layout Id' -Value $layoutId | Out-Null
    }
    $key = Join-Path $LayoutsKey $klid
    Set-ItemProperty $key 'Layout File' $Dll
    Set-ItemProperty $key 'Layout Text' $LayoutText
    New-ItemProperty $key 'Layout Display Name' -Value "@%SystemRoot%\system32\$Dll,-1000" -PropertyType ExpandString -Force | Out-Null
}

function Install-User {
    $klid = Get-XattotKlid
    if (-not $klid) { throw "Layout registry'da topilmadi." }
    $tip = Get-XattotTip $klid
    $list = Get-WinUserLanguageList
    $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
    if (-not $uzbek) {
        $list.Add($LanguageTag)
        $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
        # A newly added language brings Windows' own Uzbek keyboard along; Tugmali takes its place.
        $uzbek.InputMethodTips.Clear()
    }
    if ($uzbek.InputMethodTips -notcontains $tip) { $uzbek.InputMethodTips.Add($tip) }
    Set-WinUserLanguageList $list -Force
}

if ($Machine) {
    Install-Machine
    return
}
Invoke-MachineStep $PSCommandPath
Install-User
Write-Host "$LayoutText örnatildi. Win+Space bilan tanlang."
Write-Host 'Röyxatda körinmasa, bir marta Sign out qilib qayta kiring.'
