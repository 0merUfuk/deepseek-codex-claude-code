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

# Distinct from the Codex target on purpose: this should hold a DIFFERENT
# DeepSeek API key than the Codex profile's deepseek-api-codex target. It's
# the distinct keys (not just the distinct target names) that let each
# tool's usage be attributed separately on the DeepSeek dashboard, and let
# you rotate one without touching the other.
$token = & $credentialHelper deepseek-api-claudecode
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($token)) {
    [Console]::Error.WriteLine("claude-deepseek: no readable credential for target 'deepseek-api-claudecode' — see docs/setup-claude-code.md")
    exit 1
}

$env:ANTHROPIC_AUTH_TOKEN = $token
Remove-Variable token

$env:ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"

# "[1m]" IS a real Claude Code client-side convention — not doc-page noise.
# Claude Code strips it before the model ID hits the wire, but uses its
# presence to assume the large context window and adds Anthropic's
# context-1m beta header. Without it, Claude Code assumes a much smaller
# window for an unrecognized model and auto-compacts far earlier than
# CLAUDE_CODE_AUTO_COMPACT_WINDOW below (75% of the real 1,048,576-token
# window) is meant to allow. No "flash[1m]"/"haiku[1m]" variant exists, so
# the flash/haiku-tier line below correctly has no suffix.
$env:ANTHROPIC_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro[1m]"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"
$env:CLAUDE_CODE_EFFORT_LEVEL = "max"
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = "786432"

# Keep provider credentials out of shell commands, hooks, and MCP subprocesses.
$env:CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1"

# Claude Code's /model picker always lists the full built-in catalog
# (Opus/Sonnet/Haiku *and* any other native models such as Fable) alongside
# whatever aliases ANTHROPIC_DEFAULT_* defines. Overriding the three tier
# aliases does not remove the others, and picking one while ANTHROPIC_BASE_URL
# points at DeepSeek doesn't reliably fail — DeepSeek's Anthropic-compatible
# layer currently maps Claude-style model names onto its own models, so the
# request could be silently served by a different DeepSeek model instead.
# modelPicker with replaceBuiltInOptions hides the built-in lineup entirely,
# keeping model selection explicit instead of relying on provider-side
# aliasing behavior.
#
# switchModelsOnFlag:false is load-bearing, not cosmetic: with it left at
# its (commonly default-on) value, a claude-deepseek run has been observed
# to persist a DeepSeek model id into the NORMAL ~/.claude/settings.json
# "model" field afterwards — corrupting what plain `claude` starts with
# next time. Forcing it false here is scoped to this session only via
# --settings; it does not change normal `claude`'s own preference.
$deepseekSettings = '{"switchModelsOnFlag":false,"modelPicker":{"replaceBuiltInOptions":true,"options":[{"model":"deepseek-v4-pro[1m]","label":"DeepSeek V4 Pro","description":"High-capability DeepSeek model, 1M context"},{"model":"deepseek-v4-flash","label":"DeepSeek V4 Flash","description":"Fast/lightweight DeepSeek model"}]}}'

claude --settings $deepseekSettings @args
