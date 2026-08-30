# Isolated Claude Code + DeepSeek setup (macOS, Linux, Windows)

DeepSeek officially supports Claude Code through its Anthropic-compatible API at:

```text
https://api.deepseek.com/anthropic
```

The mechanism is different from Codex. The goal is the same operational property:

```text
claude            -> normal Claude Code path
claude-deepseek   -> explicit DeepSeek path
```

**Platform status:** the macOS and Windows paths are verified end to end (see [docs/sources.md](sources.md)) — Windows independently, by someone other than the author. The Linux path follows the same design and uses well-documented OS APIs, but hasn't been run on a Linux machine as part of preparing this kit — verify each step yourself the first time, the same way macOS and Windows were.

## 0. Preconditions

- Claude Code installed and working normally;
- DeepSeek API key stored in your OS's secret store, under a service/target dedicated to this tool, e.g. `deepseek-api-claudecode` (macOS Keychain, Linux Secret Service, or Windows Credential Manager);
- current DeepSeek and Claude Code documentation checked before use.

## 1. Store the credential

Use a distinct DeepSeek API key for Claude Code — not the same key used for the Codex profile in this kit — under its own service/target name (`deepseek-api-claudecode`, separate from Codex's `deepseek-api-codex`). See the README's "Why two distinct DeepSeek API keys" for why that matters.

### macOS

```bash
security add-generic-password -a "$USER" -s "deepseek-api-claudecode" -w -U
```

`security` prompts for the value directly — it won't be echoed or written to shell history.

### Linux

```bash
secret-tool store --label="DeepSeek API key (claude-code)" service deepseek-api-claudecode account "$USER"
```

Requires a running Secret Service provider (GNOME Keyring, KWallet via ksecrets, or similar) — typical on a desktop session, often absent on headless/server Linux.

### Windows

```powershell
.\scripts\windows\deepseek-credential-token.ps1 -Store deepseek-api-claudecode
```

Prompts via `Read-Host -AsSecureString` (input hidden) and writes to Windows Credential Manager.

Run whichever of the above matches your OS yourself, in an interactive terminal — none of these echo the value, write it to shell/command history, or expose it to an agent running the rest of this setup.

## 2. Install the isolated launcher

### macOS / Linux

```bash
mkdir -p ~/.local/bin
cp scripts/claude-deepseek ~/.local/bin/claude-deepseek
chmod 700 ~/.local/bin/claude-deepseek
```

Also install the shared credential helper if you haven't already (see [docs/setup-codex.md](setup-codex.md) step 2) — `claude-deepseek` calls `deepseek-credential-token` on `PATH`.

### Windows

Copy `scripts\windows\claude-deepseek.ps1` next to `deepseek-credential-token.ps1` (step 1) — `claude-deepseek.ps1` looks for it in the same directory as itself.

The launcher follows DeepSeek's current Claude Code integration values but keeps them process-scoped instead of writing them into your shell profile or normal Claude settings.

DeepSeek documents something close to:

```text
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_MODEL=deepseek-v4-pro[1m]
ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]
ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro[1m]
ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
CLAUDE_CODE_EFFORT_LEVEL=max
CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432
```

**The `[1m]` suffix is real and load-bearing, not doc noise** — it's a Claude Code client-side convention that unlocks the model's real ~1,048,576-token context window (without it, Claude Code assumes 200,000 tokens and auto-compacts far earlier than `CLAUDE_CODE_AUTO_COMPACT_WINDOW` above intends). Keep it only on the Opus/Sonnet-tier lines; no such variant exists for Haiku/flash. Verified on macOS by checking the wire, not the docs — see [docs/sources.md](sources.md) for how, and reproduce it yourself if you want to confirm on Linux/Windows:

```bash
ANTHROPIC_LOG=debug claude-deepseek -p "hi" 2>&1 | grep -E "model:|anthropic-beta"
```

(`$env:ANTHROPIC_LOG='debug'` on Windows.)

A real risk worth checking for regardless: a `claude-deepseek` run has been observed leaving a DeepSeek model id in the **normal** `~/.claude/settings.json`, breaking plain `claude` afterward. The fix is in the launcher (step 3) — see step 4 to verify it's holding.

The wrapper gets `ANTHROPIC_AUTH_TOKEN` from the OS secret store at launch time.

It also sets:

```text
CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
```

Claude Code documents this switch for removing authentication credentials from Bash commands, hooks, and MCP subprocesses. That reduces the exposure created by using environment-based provider auth.

## 3. Hide native models from the `/model` picker

Claude Code's `/model` picker still lists every built-in model (Opus, Sonnet, Haiku, Fable) alongside the DeepSeek aliases — overriding the three tiers relabels those slots, it doesn't remove the others. Picking a native one while `ANTHROPIC_BASE_URL` points at DeepSeek isn't guaranteed to fail cleanly: DeepSeek's Anthropic-compatible layer can silently serve it from a different DeepSeek model instead of erroring, so the model you picked and the model that answered can quietly diverge. Hiding the picker keeps that explicit instead of leaving it to chance.

The launcher does this with a session-scoped `modelPicker` setting via `--settings` (normal `claude` is untouched), and forces `switchModelsOnFlag` off in the same payload to stop the settings.json persistence risk from step 2:

```bash
exec claude --settings '{"switchModelsOnFlag":false,"modelPicker":{"replaceBuiltInOptions":true,"options":[
  {"model":"deepseek-v4-pro[1m]","label":"DeepSeek V4 Pro","description":"High-capability DeepSeek model, 1M context"},
  {"model":"deepseek-v4-flash","label":"DeepSeek V4 Flash","description":"Fast/lightweight DeepSeek model"}
]}}' "$@"
```

(Same payload on Windows, via `claude --settings $deepseekSettings @args` in `claude-deepseek.ps1`.)

After installing, open a `claude-deepseek` session and check `/model` — you should see only the two DeepSeek rows, nothing else.

## 4. Verify isolation

Check the normal model default before touching anything:

**macOS / Linux:**
```bash
python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json'))['model'])"
claude
```

**Windows:**
```powershell
python -c "import json; print(json.load(open(r'$env:USERPROFILE\.claude\settings.json'))['model'])"
claude
```

Confirm your normal Claude Code authentication/model path is unchanged.

Then:

```bash
claude-deepseek
```

(On Windows: `.\claude-deepseek.ps1`.)

Run a small non-sensitive test and verify that new usage appears in the DeepSeek dashboard. Afterwards, re-run the `settings.json` check above — the `model` value must be identical to what it was before. If it changed, the `switchModelsOnFlag` fix isn't holding on your installed version; restore the value manually and treat this as a blocking issue, not a cosmetic one.

## 5. Why a launcher instead of global exports?

DeepSeek's official quick-start tells users to export the required `ANTHROPIC_*` and `CLAUDE_CODE_*` values. That is sufficient for a session, but placing them permanently in a shell profile (or in a Windows user/system environment variable) changes future Claude Code invocations.

The wrapper scopes the override to one command's process (and PowerShell's `$env:` assignments are process-scoped the same way `export` is in bash) and keeps normal `claude` unchanged.

## 6. Same objective, different mechanism

```text
Codex CLI                         Claude Code
    |                                 |
profile-v2 layer                process-scoped env
    |                                 |
Responses API                  Anthropic-compatible API
    |                                 |
    +---------- DeepSeek V4 ----------+
```

That difference is useful for the later experiment: hold the backend approximately constant and examine what changes when the harness changes.

## 7. Rollback

**macOS:**
```bash
rm ~/.local/bin/claude-deepseek
security delete-generic-password -a "$USER" -s "deepseek-api-claudecode"
```

**Linux:**
```bash
rm ~/.local/bin/claude-deepseek
secret-tool clear service deepseek-api-claudecode account "$USER"
```

**Windows:**
```powershell
Remove-Item .\claude-deepseek.ps1
cmdkey /delete:deepseek-api-claudecode
```

`~/.claude/settings.json` (`%USERPROFILE%\.claude\settings.json` on Windows) should not be modified by this setup — the launcher forces `switchModelsOnFlag: false` specifically to guarantee that (see step 2/4 above) — but if you ever see its `model` field change after a `claude-deepseek` run, that's the thing to check first, not something to assume away.
