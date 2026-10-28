# Shared by install.ps1 and uninstall.ps1.

$Dll = 'kbduzxt.dll'
$LayoutText = 'Özbekça Tugmali (Xattot)'
$LanguageId = '0443'
$LanguageTag = 'uz-Latn-UZ'
$LayoutsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
$LayoutDirs = @{
    (Join-Path $env:SystemRoot 'System32') = 'native'
    (Join-Path $env:SystemRoot 'SysWOW64') = 'wow64'
}

function Get-XattotKlid {
    Get-ChildItem $LayoutsKey |
        Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq $Dll } |
        Select-Object -First 1 -ExpandProperty PSChildName
}

function Get-XattotTip([string]$Klid) {
    "${LanguageId}:$($Klid.ToUpper())"
}

function Test-Admin {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# System32 and the registry need an administrator; the language list is the user's own, so only
# this half runs elevated and the rest stays with the account that will type.
function Invoke-MachineStep([string]$Script) {
    if (Test-Admin) {
        & $Script -Machine
        return
    }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Script`"", '-Machine')
    # Windows PowerShell at its fixed path: under PowerShell 7, $PSHOME has no powershell.exe.
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $process = Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Administrator qismi xato bilan tugadi (kod $($process.ExitCode))."
    }
}

# A layout DLL Windows has loaded cannot be overwritten or deleted, but it can be renamed:
# the renamed copy is deleted at the next restart.
function Remove-InUse([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    try {
        Remove-Item $Path -Force
        return
    } catch { }
    $old = "$Path.$([guid]::NewGuid().ToString('N')).old"
    Move-Item $Path $old
    $delayUntilReboot = 4
    $null = (Get-Native)::MoveFileEx($old, $null, $delayUntilReboot)
}

# The machine Windows runs on, whatever this PowerShell is: x64 PowerShell on an ARM64 PC
# reports AMD64 in PROCESSOR_ARCHITECTURE and in .NET.
function Get-NativeArchitecture {
    $process = [uint16]0
    $native = [uint16]0
    if (-not (Get-Native)::IsWow64Process2((Get-Native)::GetCurrentProcess(), [ref]$process, [ref]$native)) {
        throw 'IsWow64Process2 failed.'
    }
    @{ 0x8664 = 'x64'; 0xAA64 = 'arm64' }[[int]$native]
}

function Get-Native {
    if (-not ('Xattot.Native' -as [type])) {
        Add-Type -Namespace Xattot -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool MoveFileEx(string from, string to, int flags);
[DllImport("kernel32.dll")]
public static extern IntPtr GetCurrentProcess();
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool IsWow64Process2(IntPtr process, out ushort processMachine, out ushort nativeMachine);
'@
    }
    [Xattot.Native]
}
