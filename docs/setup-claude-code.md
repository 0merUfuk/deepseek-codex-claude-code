# Isolated Claude Code + DeepSeek setup on macOS

DeepSeek officially supports Claude Code through its Anthropic-compatible API at:

```text
https://api.deepseek.com/anthropic
```

The mechanism is different from Codex. The goal is the same operational property:

```text
claude            -> normal Claude Code path
claude-deepseek   -> explicit DeepSeek path
```

## 0. Preconditions

- Claude Code installed and working normally;
- DeepSeek API key stored in macOS Keychain under a service dedicated to this tool, e.g. `deepseek-api-claudecode`;
- current DeepSeek and Claude Code documentation checked before use.

## 1. Store the credential

Use a distinct DeepSeek API key for Claude Code — not the same key used for the Codex profile in this kit — and store it under its own Keychain service (e.g. `deepseek-api-claudecode`, separate from Codex's `deepseek-api-codex`). It's the distinct key, not just the distinct service name, that keeps DeepSeek dashboard usage attributable per tool and lets you rotate one without touching the other; storing the same key under a second service name would not give you either property.

```bash
security add-generic-password -a "$USER" -s "deepseek-api-claudecode" -w -U
```

Run this yourself in an interactive terminal — `security` prompts for the value directly, so it's never echoed, written to shell history, or seen by an agent running the rest of this setup.

## 2. Install the isolated launcher

```bash
mkdir -p ~/.local/bin
cp scripts/claude-deepseek ~/.local/bin/claude-deepseek
chmod 700 ~/.local/bin/claude-deepseek
```

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

**On the `[1m]` suffix — verified, not doc noise.** It's tempting to assume `deepseek-v4-pro[1m]` is a doc-page rendering artifact (an earlier version of this kit made exactly that assumption and stripped it — that was wrong). It's a real Claude Code client-side convention: Claude Code's own model-alias list includes `sonnet[1m]`, `opus[1m]`, `fable[1m]` (no `flash[1m]`/`haiku[1m]` — matches the values above), and it strips the suffix before the model ID reaches the wire while using its presence to assume the model's real (large) context window and add Anthropic's `context-1m` beta header. Confirmed empirically, not from docs:

```bash
ANTHROPIC_LOG=debug claude-deepseek -p "hi" 2>&1 | grep -E "model:|anthropic-beta"
#   model: "deepseek-v4-pro"                              <- suffix stripped for the wire
#   "anthropic-beta": "...,context-1m-2025-08-07,..."     <- added because of the suffix
```

Without the suffix, Claude Code treats the model as fully unrecognized and assumes a **200,000-token** window regardless of what the model can actually do (confirmed via the exact warning text Claude Code prints for an unrecognized model) — meaning `CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432` above (75% of DeepSeek's real 1,048,576-token window) would be configured against a budget Claude Code doesn't believe exists, and the session would auto-compact far earlier than necessary. Keep the suffix on the Opus/Sonnet-tier lines; don't add it to the Haiku/flash line, since no such variant exists for that tier.

**A real persistence risk this surfaced, worth checking for regardless of the above:** at one point during testing, a `claude-deepseek` run left `deepseek-v4-flash` written into the **normal** `~/.claude/settings.json`'s `"model"` field — meaning plain `claude` afterwards tried to use it against the real Anthropic API and failed. The suspected mechanism is the `switchModelsOnFlag` setting (persists a model change as your new default) firing on an internal alias resolution, not on anything this launcher does on purpose. The fix is included in the launcher below (`"switchModelsOnFlag":false` in its `--settings` payload) and held up across repeated test runs afterwards, but treat this as a known risk to actively check for — see step 4.

The wrapper gets `ANTHROPIC_AUTH_TOKEN` from Keychain at launch time.

It also sets:

```text
CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
```

Claude Code documents this switch for removing authentication credentials from Bash commands, hooks, and MCP subprocesses. That reduces the exposure created by using environment-based provider auth.

## 3. Hide native models from the `/model` picker

Claude Code's `/model` picker always lists the full built-in model lineup (Opus, Sonnet, Haiku, and any other native model such as Fable) alongside whatever `ANTHROPIC_DEFAULT_*` aliases you've set. Overriding the three tier aliases relabels three of those slots — it does not remove the others. If you pick a native model while `ANTHROPIC_BASE_URL` still points at DeepSeek, the request still goes to DeepSeek — but that's not guaranteed to fail cleanly. DeepSeek's Anthropic-compatible layer currently maps Claude-style model names onto its own models, so the request can be silently served by whatever DeepSeek model that name happens to alias to, rather than erroring. That's arguably worse than a clean failure: the model you picked in `/model` and the model that actually served the request can silently diverge. Hiding the picker sidesteps the question of which behavior to expect and keeps model selection explicit.

The launcher works around this with a session-scoped `modelPicker` setting passed via `--settings`, which only applies to `claude-deepseek` invocations — normal `claude` and its picker are untouched. It also forces `switchModelsOnFlag` off in the same payload, for the persistence risk noted above:

```bash
exec claude --settings '{"switchModelsOnFlag":false,"modelPicker":{"replaceBuiltInOptions":true,"options":[
  {"model":"deepseek-v4-pro[1m]","label":"DeepSeek V4 Pro","description":"High-capability DeepSeek model, 1M context"},
  {"model":"deepseek-v4-flash","label":"DeepSeek V4 Flash","description":"Fast/lightweight DeepSeek model"}
]}}' "$@"
```

After installing, open a `claude-deepseek` session and check `/model` — you should see only the two DeepSeek rows, nothing else.

## 4. Verify isolation

Check the normal model default before touching anything:

```bash
python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json'))['model'])"
claude
```

Confirm your normal Claude Code authentication/model path is unchanged.

Then:

```bash
claude-deepseek
```

Run a small non-sensitive test and verify that new usage appears in the DeepSeek dashboard. Afterwards, re-run the `settings.json` check above — the `model` value must be identical to what it was before. If it changed, the `switchModelsOnFlag` fix isn't holding on your installed version; restore the value manually and treat this as a blocking issue, not a cosmetic one.

## 5. Why a launcher instead of global exports?

DeepSeek's official quick-start tells users to export the required `ANTHROPIC_*` and `CLAUDE_CODE_*` values. That is sufficient for a session, but placing them permanently in a shell profile changes future Claude Code invocations.

The wrapper scopes the override to one command and keeps normal `claude` unchanged.

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

```bash
rm ~/.local/bin/claude-deepseek
security delete-generic-password -a "$USER" -s "deepseek-api-claudecode"
```

`~/.claude/settings.json` should not be modified by this setup — the launcher forces `switchModelsOnFlag: false` specifically to guarantee that (see step 2/4 above) — but if you ever see its `model` field change after a `claude-deepseek` run, that's the thing to check first, not something to assume away.
