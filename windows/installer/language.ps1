# Adds the Tugmali keyboard to, or removes it from, the current user's language list.
# The installer runs it as the signed-in user, since the list belongs to that account.
param(
    [Parameter(Mandatory = $true)][string]$Tip,
    [switch]$Remove
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
        # A newly added language brings Windows' own Uzbek keyboard along; Tugmali takes its place.
        $uzbek.InputMethodTips.Clear()
    }
    if ($uzbek.InputMethodTips -notcontains $Tip) { $uzbek.InputMethodTips.Add($Tip) }
}

Set-WinUserLanguageList $list -Force
