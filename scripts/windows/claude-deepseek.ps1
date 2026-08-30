<#
.SYNOPSIS
Launches Claude Code against DeepSeek's Anthropic-compatible endpoint.

.DESCRIPTION
Normal `claude` is untouched: every DeepSeek-specific variable here is set
only in this process's environment ($env:, not [Environment]::SetEnvironmentVariable
with a persisted scope), so nothing survives past this process and its
children. Mirrors scripts/claude-deepseek (macOS/Linux).
#>
$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("claude-deepseek: claude CLI not found on PATH")
    exit 127
}

$credentialHelper = Join-Path $PSScriptRoot 'deepseek-credential-token.ps1'
if (-not (Test-Path $credentialHelper)) {
    [Console]::Error.WriteLine("claude-deepseek: deepseek-credential-token.ps1 not found next to this script")
    exit 127
}

# A different DeepSeek key than Codex's deepseek-api-codex — see README
# "Why two distinct DeepSeek API keys".
$token = & $credentialHelper deepseek-api-claudecode
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($token)) {
    [Console]::Error.WriteLine("claude-deepseek: no readable credential for target 'deepseek-api-claudecode' — see docs/setup-claude-code.md")
    exit 1
}

$env:ANTHROPIC_AUTH_TOKEN = $token
Remove-Variable token

$env:ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"

# "[1m]" is a real, load-bearing Claude Code convention, not doc noise —
# it unlocks the real context window. See docs/sources.md for how that was
# verified. No "flash[1m]"/"haiku[1m]" variant exists, so that tier below
# correctly has no suffix.
$env:ANTHROPIC_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"
$env:CLAUDE_CODE_EFFORT_LEVEL = "max"
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = "786432"

# Keep provider credentials out of shell commands, hooks, and MCP subprocesses.
$env:CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1"

# modelPicker/replaceBuiltInOptions hides native models so one can't be
# picked while ANTHROPIC_BASE_URL points at DeepSeek (DeepSeek can silently
# remap a native name to a different model instead of failing).
# switchModelsOnFlag:false stops a DeepSeek model id from leaking into the
# NORMAL settings.json — scoped to this session only. Details: docs/sources.md.
$deepseekSettings = '{"switchModelsOnFlag":false,"modelPicker":{"replaceBuiltInOptions":true,"options":[{"model":"deepseek-v4-pro[1m]","label":"DeepSeek V4 Pro","description":"High-capability DeepSeek model, 1M context"},{"model":"deepseek-v4-flash","label":"DeepSeek V4 Flash","description":"Fast/lightweight DeepSeek model"}]}}'

claude --settings $deepseekSettings @args
