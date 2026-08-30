<#
.SYNOPSIS
Windows credential helper for DeepSeek API keys. Mirrors
scripts/deepseek-credential-token (macOS Keychain / Linux Secret Service)
so the same two-key-per-harness design works on Windows, via Windows
Credential Manager (a generic credential per target name) accessed through
advapi32.dll — no third-party module required.

.DESCRIPTION
Read (default) — prints the stored key to stdout with no trailing newline.
Never logs or decorates the token; all diagnostics go to stderr. This is
what Codex's auth.command invokes and what claude-deepseek.ps1 calls to
populate ANTHROPIC_AUTH_TOKEN.

Store (-Store) — prompts for the key with input hidden (Read-Host
-AsSecureString), so the secret is never typed on the command line or left
in PowerShell history, then writes it via CredWrite.

.EXAMPLE
.\deepseek-credential-token.ps1 deepseek-api-codex

.EXAMPLE
.\deepseek-credential-token.ps1 -Store deepseek-api-codex
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetName,
    [switch]$Store
)

$ErrorActionPreference = 'Stop'

Add-Type -Namespace DeepSeek -Name CredMan -MemberDefinition @'
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
    public int Flags;
    public int Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize;
    public IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}

[DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

[DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredWrite(ref CREDENTIAL credential, int flags);

[DllImport("advapi32.dll", SetLastError = true)]
public static extern void CredFree(IntPtr cred);
'@

$CRED_TYPE_GENERIC = 1
$CRED_PERSIST_LOCAL_MACHINE = 2

if ($Store) {
    $secure = Read-Host -AsSecureString "DeepSeek API key for '$TargetName'"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ([string]::IsNullOrEmpty($plain)) {
            [Console]::Error.WriteLine("deepseek-credential-token: empty input, nothing stored")
            exit 1
        }
        $blob = [System.Text.Encoding]::Unicode.GetBytes($plain)
        $blobPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($blob.Length)
        try {
            [System.Runtime.InteropServices.Marshal]::Copy($blob, 0, $blobPtr, $blob.Length)
            $cred = New-Object DeepSeek.CredMan+CREDENTIAL
            $cred.Type = $CRED_TYPE_GENERIC
            $cred.TargetName = $TargetName
            $cred.CredentialBlobSize = $blob.Length
            $cred.CredentialBlob = $blobPtr
            $cred.Persist = $CRED_PERSIST_LOCAL_MACHINE
            $cred.UserName = $env:USERNAME
            $ok = [DeepSeek.CredMan]::CredWrite([ref]$cred, 0)
            if (-not $ok) {
                $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                [Console]::Error.WriteLine("deepseek-credential-token: CredWrite failed (Win32 error $err)")
                exit 1
            }
            Write-Host "deepseek-credential-token: stored '$TargetName' in Windows Credential Manager."
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($blobPtr)
        }
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    exit 0
}

# ---- read mode (default) ----
$credPtr = [IntPtr]::Zero
$found = [DeepSeek.CredMan]::CredRead($TargetName, $CRED_TYPE_GENERIC, 0, [ref]$credPtr)

if (-not $found) {
    [Console]::Error.WriteLine("deepseek-credential-token: no credential in Windows Credential Manager (target=$TargetName)")
    [Console]::Error.WriteLine("deepseek-credential-token: store it with:")
    [Console]::Error.WriteLine("  .\deepseek-credential-token.ps1 -Store $TargetName")
    exit 1
}

try {
    $cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure[DeepSeek.CredMan+CREDENTIAL]($credPtr)
    if ($cred.CredentialBlobSize -eq 0) {
        [Console]::Error.WriteLine("deepseek-credential-token: credential found but empty (target=$TargetName)")
        exit 1
    }
    $bytes = New-Object byte[] $cred.CredentialBlobSize
    [System.Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $bytes, 0, $cred.CredentialBlobSize)
    # Windows Credential Manager stores the password blob as UTF-16LE.
    $token = [System.Text.Encoding]::Unicode.GetString($bytes).TrimEnd([char]0)
    [Console]::Out.Write($token)
}
finally {
    [DeepSeek.CredMan]::CredFree($credPtr)
}
