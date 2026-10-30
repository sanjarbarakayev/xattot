# Adds a keyboard (Tugmali or the input method) to, or removes it from, the current user's language list.
# The installer runs it as the signed-in user, since the list belongs to that account.
# -First puts a newly added keyboard at the top of the Uzbek list, where Windows picks it by default.
param(
    [Parameter(Mandatory = $true)][string]$Tip,
    [switch]$Remove,
    [switch]$First
)

$ErrorActionPreference = 'Stop'
$list = Get-WinUserLanguageList

if ($Remove) {
    foreach ($language in @($list | Where-Object { $_.InputMethodTips -contains $Tip })) {
        [void]$language.InputMethodTips.Remove(($language.InputMethodTips | Where-Object { $_ -eq $Tip }))
        # Windows refills a language left without a keyboard with its default one, so drop it instead.
        if ($language.InputMethodTips.Count -eq 0) { [void]$list.Remove($language) }
    }
} else {
    $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
    if (-not $uzbek) {
        $list.Add('uz-Latn-UZ')
        $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
        # A newly added language brings Windows' own Uzbek keyboard along; Xattot's take its place.
        $uzbek.InputMethodTips.Clear()
    }
    if ($uzbek.InputMethodTips -notcontains $Tip) {
        if ($First) { $uzbek.InputMethodTips.Insert(0, $Tip) } else { $uzbek.InputMethodTips.Add($Tip) }
    }
}

Set-WinUserLanguageList $list -Force
