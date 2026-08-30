<#
.SYNOPSIS
Launches Codex against DeepSeek via the "deepseek" profile-v2 config.

.DESCRIPTION
Auth is command-backed (model_providers.deepseek.auth.command), so no
secret is exported into this process or Codex's environment. Mirrors
scripts/codex-deepseek (macOS/Linux).
#>
$ErrorActionPreference = 'Stop'

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("codex-deepseek: codex CLI not found on PATH")
    exit 127
}

$credentialHelper = Join-Path $PSScriptRoot 'deepseek-credential-token.ps1'
if (-not (Test-Path $credentialHelper)) {
    [Console]::Error.WriteLine("codex-deepseek: deepseek-credential-token.ps1 not found next to this script")
    exit 127
}

# Fail before opening Codex if the credential is missing.
& $credentialHelper deepseek-api-codex *> $null
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("codex-deepseek: no readable credential for target 'deepseek-api-codex' — see docs/setup-codex.md")
    exit 1
}

codex --profile deepseek @args
