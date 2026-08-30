# Agent prompt: install an isolated Claude Code + DeepSeek launcher

Configure my existing Claude Code installation so DeepSeek is available through `claude-deepseek` while normal `claude` remains unchanged. This works on macOS, Linux, and Windows — detect which one you're on first and follow that branch throughout; don't mix steps from different platforms.

## Non-negotiable requirements

- Do not permanently export DeepSeek `ANTHROPIC_*` or `CLAUDE_CODE_*` variables in my shell profile, or (on Windows) via `[Environment]::SetEnvironmentVariable` with a persisted scope. Process-scoped only (`export` in bash, `$env:` in PowerShell).
- Do not overwrite normal Claude settings/authentication just to enable DeepSeek. This includes `~/.claude/settings.json`'s (`%USERPROFILE%\.claude\settings.json` on Windows) persisted `model` field: check it before and after every test run of the launcher you build, not just once. Claude Code's `switchModelsOnFlag` setting can silently persist a model-alias resolution (even an internal/background one, not necessarily the one you interacted with) into that file — confirmed to happen in practice, not a hypothetical. If your installed version has this setting, force it off for the launcher's session only (e.g. via a session-scoped `--settings` payload), and verify the persisted file is unchanged across several runs, not just one, before considering this requirement satisfied.
- Do not store the DeepSeek API key in plaintext files.
- Store the credential in the OS's native secret store under a service/target name dedicated to this tool, e.g. `deepseek-api-claudecode` — macOS Keychain, the Linux Secret Service (via `secret-tool`), or Windows Credential Manager (via the bundled `scripts/windows/deepseek-credential-token.ps1 -Store`). If I also run a DeepSeek launcher for another coding agent (Codex, etc.), use a **different DeepSeek API key** for each tool, each under its own service/target name — do not store the same key under two names. It's the distinct keys that keep per-tool usage attributable on the DeepSeek dashboard and let me rotate one credential without touching the other; separate names alone do not provide that.
- Whatever the OS, the credential-store step must be run by me directly in an interactive terminal (or, on Windows, via the bundled store script's own secure prompt) — never type or paste the raw key into a command you run on my behalf, and never accept it as a prompt argument, so you never see or handle the plaintext key.
- Read the current official DeepSeek Claude Code integration and Claude Code environment-variable documentation before choosing values. Do not copy a value verbatim from a rendered doc page without checking whether formatting markup (e.g. a bracketed annotation appended to a model name) has been mixed into the literal value.
- Enable Claude Code's subprocess credential scrubbing if supported by the installed version.
- Verify actual provider usage before claiming success.
- **macOS and Linux are verified working designs; the Windows path is a reasoned but unverified port** (no Windows machine was available to test it while this kit was written). If you're on Windows, say so explicitly when you report completion, and be more conservative about claiming something works versus something merely ran without an error.

## Desired architecture

```text
claude
  -> existing normal Claude Code path

claude-deepseek
  -> OS secret store, service/target "deepseek-api-claudecode"
     (macOS Keychain / Linux Secret Service / Windows Credential Manager)
  -> process-scoped DeepSeek/Anthropic variables
  -> CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
  -> claude
  -> https://api.deepseek.com/anthropic
```

## Current reference values

As of when this prompt was written, DeepSeek documents something close to:

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

**On the `[1m]` suffix — don't assume it's doc noise without checking the wire.** A bracketed annotation appended to a model name in a vendor's docs could be genuine doc-page formatting, or it could be a real convention the *client* (Claude Code, here) interprets specially. Don't resolve this by reading a paraphrase of the docs page and guessing — resolve it by sending the request both ways and inspecting what actually goes out:

```bash
ANTHROPIC_LOG=debug claude -p "hi" 2>&1 | grep -E "model:|anthropic-beta"
```

(On Windows: `$env:ANTHROPIC_LOG='debug'; claude -p "hi" 2>&1 | Select-String "model:|anthropic-beta"`.)

In this case, `[1m]` turned out to be real on macOS: Claude Code strips it before the literal model ID hits the wire, but its presence makes Claude Code assume the model's real (large) context window and adds Anthropic's `context-1m` beta header — confirmed this way, not from a doc paraphrase. Without it, Claude Code assumes a **200,000-token** window for any model it doesn't recognize, regardless of what the model can actually do, and auto-compacts accordingly — which silently defeats a large `CLAUDE_CODE_AUTO_COMPACT_WINDOW` value like the one above. Keep the suffix only where the vendor's docs put it (here: Opus/Sonnet-tier values, not the Haiku/flash-tier one) rather than adding it everywhere on the assumption that more is safer. This is Claude Code client-side logic, not OS-specific, so it should behave identically on Linux/Windows — but re-verify with the wire check above rather than assuming, especially on Windows.

## Launcher requirements

**macOS / Linux:** create `~/.local/bin/claude-deepseek` that:

1. verifies `claude` exists;
2. reads the DeepSeek key from the OS secret store without printing it (via a shared `deepseek-credential-token <service>` helper, auto-detecting macOS Keychain vs. Linux Secret Service);
3. sets `ANTHROPIC_AUTH_TOKEN` only in the launcher process;
4. sets current DeepSeek-recommended base URL/model variables;
5. sets `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` if the current Claude Code version supports it;
6. hides Claude's native model catalog from the `/model` picker for this session only, so a native model (e.g. Opus, Sonnet, Fable) can't be accidentally selected while `ANTHROPIC_BASE_URL` points at DeepSeek. This isn't only about a request failing outright — DeepSeek's Anthropic-compatible layer currently maps Claude-style model names onto DeepSeek models, so an accidental native selection could be silently served by a different DeepSeek model instead of erroring. Keep model selection explicit rather than relying on provider-side aliasing behavior that could change. Claude Code's `/model` picker always lists the full built-in lineup alongside any `ANTHROPIC_DEFAULT_*` aliasing, and overriding the three tier aliases does not remove the others. Check whether the installed Claude Code version supports a session-scoped `modelPicker` setting (e.g. via `--settings`) with a "replace built-in options" flag, and use it if so; if not supported, warn the user in the launcher's normal-path documentation rather than silently leaving the wrong models selectable;
7. in the same `--settings` payload, forces off whatever setting controls persisting a model switch as the new default (e.g. `switchModelsOnFlag`), if the installed version has one — see the non-negotiable requirement above;
8. executes `claude "$@"`;
9. leaves normal `claude` unchanged.

**Windows:** create `claude-deepseek.ps1` (kept alongside `deepseek-credential-token.ps1`) with the same nine properties, using `$env:` assignments in place of `export`, `@args` in place of `"$@"`, and PowerShell's own command-existence checks (`Get-Command`) in place of `command -v`. The credential read goes through `deepseek-credential-token.ps1`'s Windows Credential Manager backend instead of a Keychain/Secret Service call.

## Verification gates

1. normal `claude` still uses the original path;
2. `claude-deepseek` starts successfully;
3. a minimal non-sensitive request succeeds;
4. provider-side usage confirms the DeepSeek route;
5. no secret appears in persistent config, Git changes, logs, or shell output;
6. the `/model` picker under `claude-deepseek` does not offer a native Anthropic model that could be silently remapped by the provider or otherwise misrouted if selected;
7. `~/.claude/settings.json`'s (or `%USERPROFILE%\.claude\settings.json`'s) `model` field is byte-identical before and after **at least three separate** `claude-deepseek` runs, not just one — a single clean run is not sufficient evidence this is fixed, since the persistence bug this guards against did not reproduce on every run either.

Do not claim completion until the applicable checks pass.
