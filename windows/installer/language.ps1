# Adds Xattot's keyboards to, or removes them from, the current user's language list.
# The installer runs it as the signed-in user, since the list belongs to that account.
# -Tips lists them comma-separated, in order: they go to the top of the Uzbek list in that order,
# and Windows picks the first one by default. One call writes them all, since every
# Set-WinUserLanguageList lets Windows put its own default keyboard back into a new language.
param(
    [Parameter(Mandatory = $true)][string]$Tips,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$wanted = @($Tips -split ',' | Where-Object { $_ })
$list = Get-WinUserLanguageList

function Remove-Tip($language, [string]$tip) {
    foreach ($found in @($language.InputMethodTips | Where-Object { $_ -eq $tip })) {
        [void]$language.InputMethodTips.Remove($found)
    }
}

if ($Remove) {
    foreach ($language in @($list)) {
        $had = $language.InputMethodTips.Count
        foreach ($tip in $wanted) { Remove-Tip $language $tip }
        # Windows refills a language left without a keyboard with its default one, so drop it instead.
        if ($had -gt 0 -and $language.InputMethodTips.Count -eq 0) { [void]$list.Remove($language) }
    }
} else {
    $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
    if (-not $uzbek) {
        $list.Add('uz-Latn-UZ')
        $uzbek = $list | Where-Object { $_.LanguageTag -like 'uz-Latn*' } | Select-Object -First 1
        # A newly added language brings Windows' default keyboard along; Xattot's take its place.
        $uzbek.InputMethodTips.Clear()
    }
    foreach ($tip in $wanted) { Remove-Tip $uzbek $tip }
    for ($i = 0; $i -lt $wanted.Count; $i++) { $uzbek.InputMethodTips.Insert($i, $wanted[$i]) }
}

Set-WinUserLanguageList $list -Force
