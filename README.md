# DeepSeek with Codex + Claude Code

> **Setting this up with an AI coding agent?** Point it at [`prompts/install-codex-deepseek.md`](prompts/install-codex-deepseek.md) and/or [`prompts/install-claude-deepseek.md`](prompts/install-claude-deepseek.md) and have it read and follow the file end to end — they're written as agent instructions, with verification gates and rollback steps built in. One step can't be automated on purpose: storing the DeepSeek API key is designed to require you, not the agent, typing it into a secure, non-echoing prompt — see "Security / credential isolation" below.

A reproducible macOS, Linux, and Windows kit for running DeepSeek through **Codex CLI** and **Claude Code** while keeping both normal tool paths unchanged: one provider, two harnesses, two protocol paths.

The two harnesses reach DeepSeek through different compatibility layers, and are not necessarily configured with the exact same model — Codex uses `deepseek-v4-flash`; Claude Code's launcher uses `deepseek-v4-pro[1m]` as its primary model and `deepseek-v4-flash` for its lighter tier. Don't read this kit as "same model, different harness" — a controlled comparison that holds the model constant across harnesses is future work, not something this kit already demonstrates.

```text
Codex       -> opt-in profile          -> Responses API             -> DeepSeek
Claude Code -> process-scoped override -> Anthropic-compatible API  -> DeepSeek
```

Both integrations are live and verified **on macOS**; the Linux and Windows paths are a reasoned port built on the equivalent native secret store for each OS, not yet run on either platform (see "Current compatibility" below). Each harness uses its own DeepSeek API key, stored under a separate service/target name in the OS's native secret store — macOS Keychain, the Linux Secret Service, or Windows Credential Manager. That's what keeps provider-side usage attributable per harness and lets either key be rotated independently — the separate service/target *names* are just where each key lives, not what creates the attribution.

## Evidence boundary

The DeepSeek dashboard for the original Codex workload reported:

- **211,285,901** dashboard-counted tokens
- **1,244** API requests
- **$1.67** total reported cost
- model: **`deepseek-v4-flash`**

Those figures belong to the **Codex workload only**. Claude Code has been verified end to end, but it does not yet have a comparable workload behind it. The figures are not a pricing benchmark or guarantee; DeepSeek prices cache-hit input, cache-miss input, and output tokens differently, and prices can change.

## The point of the setup

The interesting part is not only the cost result. It is the separation:

```text
coding harness  !=  model provider
```

For Codex, current `--profile` behavior layers `$CODEX_HOME/<name>.config.toml` over the base user config. This kit uses `~/.codex/deepseek.config.toml`, so normal `codex` keeps the base configuration and `codex-deepseek` opts into DeepSeek.

The current hardened credential path is:

```text
OS secret store (deepseek-api-codex)
  macOS Keychain / Linux Secret Service / Windows Credential Manager
      |
deepseek-credential-token
      |
Codex command-backed provider auth
      |
~/.codex/deepseek.config.toml
      |
DeepSeek Responses API
```

No API key is stored in TOML or exported into the Codex process environment.

Claude Code uses a different mechanism because DeepSeek exposes an Anthropic-compatible endpoint for it. The `claude-deepseek` wrapper keeps those environment overrides process-scoped, enables Claude Code's credential scrub for subprocesses, and uses its own service/target name (`deepseek-api-claudecode`) in the same OS secret store. Normal `claude` never inherits the DeepSeek route.

**Why two distinct DeepSeek API keys instead of one shared key:** running both launchers side by side, sharing one key would make DeepSeek dashboard usage indistinguishable between Codex and Claude Code, and rotating the key would affect both tools at once. The two service/target names (`deepseek-api-codex`, `deepseek-api-claudecode`) are just where each key is stored — it's the keys themselves being distinct that gives you attributable dashboard usage and independent rotation. Storing one shared key under two names would not give you either property.

## Security / credential isolation

- No DeepSeek API key is ever written to TOML, JSON, shell profiles, or this repository.
- Each harness reads its key from the OS's native secret store at launch time — macOS Keychain, the Linux Secret Service, or Windows Credential Manager — into that process's environment only.
- Codex additionally never exports the key into its own process environment at all — it uses command-backed provider auth (`model_providers.deepseek.auth.command`), so the key lives only in the credential helper's stdout, consumed directly by Codex.
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` strips provider credentials from Bash commands, hooks, and MCP subprocesses spawned inside a `claude-deepseek` session.
- Both launchers are session/process-scoped: nothing is exported into a shell profile (or, on Windows, a persisted environment variable), and normal `codex` / `claude` invocations never see any of it.
- Storing the key is always an interactive, non-echoing step you run yourself — `security add-generic-password` (macOS), `secret-tool store` (Linux), or the bundled `deepseek-credential-token.ps1 -Store` (Windows, via a hidden `Read-Host` prompt). The raw key is never a command-line argument, never in shell/PowerShell history, and never seen by an agent running the rest of the setup.

## Repository contents

```text
.
├── README.md
├── LICENSE
├── CHANGELOG.md
├── docs/
│   ├── setup-codex.md         (macOS / Linux / Windows)
│   ├── setup-claude-code.md   (macOS / Linux / Windows)
│   └── sources.md
├── config/
│   └── deepseek.config.toml.example
├── scripts/
│   ├── codex-deepseek                (macOS / Linux)
│   ├── deepseek-credential-token     (macOS / Linux)
│   ├── claude-deepseek                (macOS / Linux)
│   └── windows/
│       ├── codex-deepseek.ps1
│       ├── deepseek-credential-token.ps1
│       └── claude-deepseek.ps1
└── prompts/
    ├── install-codex-deepseek.md
    └── install-claude-deepseek.md
```

## Getting started

- Codex: [docs/setup-codex.md](docs/setup-codex.md)
- Claude Code: [docs/setup-claude-code.md](docs/setup-claude-code.md)
- Reusable install prompts for an agent to run: [prompts/](prompts/)

Both setup docs cover macOS, Linux, and Windows in the same file, with a platform-specific step wherever the OS matters (mainly: which credential store, and bash vs. PowerShell scripts).

## Current compatibility

Verified **2026-08-30**, on macOS. The Linux and Windows credential/launcher paths were added the same day, built from documented OS APIs (Secret Service via `secret-tool`; Windows Credential Manager via `advapi32.dll`), but have not themselves been run on either platform — see the "Cross-platform status" note in [docs/sources.md](docs/sources.md) for exactly what that does and doesn't cover.

- DeepSeek's Codex integration uses the Responses API.
- DeepSeek currently lists V4 Flash, V4 Pro, and V4 Flash Vision Exp as supporting both Responses and Anthropic-compatible APIs.
- DeepSeek has an official Claude Code integration using `https://api.deepseek.com/anthropic`.
- current Codex CLI `--profile <name>` layers `$CODEX_HOME/<name>.config.toml` over the base config.
- current Codex supports command-backed bearer-token authentication for custom model providers — confirmed both from docs and by inspecting the installed Codex binary's own config schema.
- in the installed Codex version, `model_catalog_json` paths are tilde-expanded by the config loader; `auth.command` paths are not (it's invoked without a shell). See [docs/sources.md](docs/sources.md) for how this was verified.
- Claude Code's `/model` picker lists native models (e.g. Fable) alongside any DeepSeek aliasing unless explicitly hidden via a session-scoped `modelPicker` setting. DeepSeek's Anthropic-compatible layer currently maps Claude-style model names onto DeepSeek models, so an unhidden native selection isn't guaranteed to fail loudly — it can be silently served by a different DeepSeek model instead. The launcher hides the picker to keep model selection explicit rather than relying on that provider-side mapping behaving one way or the other. See [docs/setup-claude-code.md](docs/setup-claude-code.md).
- both DeepSeek models used here report a **1,048,576-token context window** — Codex learns this from an explicit field in `model_catalog_json`; Claude Code only learns it if the model name carries a `[1m]` suffix it recognizes (verified by inspecting a live outgoing request, not by trusting DeepSeek's docs at face value — an earlier version of this kit got this backwards and stripped the suffix as a "bug"). See [docs/sources.md](docs/sources.md).
- a pre-existing Claude Code setting, `switchModelsOnFlag`, was observed persisting a DeepSeek model id into the *normal* `~/.claude/settings.json` after a `claude-deepseek` run. The launcher forces it off for its own session; see [docs/setup-claude-code.md](docs/setup-claude-code.md) for the check to run after installing.

Always re-check [docs/sources.md](docs/sources.md) before installing or republishing version-sensitive details.

## Known caveats

- Codex and Claude Code are not necessarily configured with the same DeepSeek model (see the note near the top of this README). Any comparison between the two harnesses should control for that before drawing conclusions.
- DeepSeek's own documentation is not fully consistent about which models support the Responses API; this kit deliberately uses `deepseek-v4-flash` for Codex, which is not the disputed case. See [docs/sources.md](docs/sources.md).
- **Linux and Windows are unverified.** The design is sound and the scripts are written to the same standard as the macOS ones, but neither has been run end to end while preparing this kit. Run the verification steps in `docs/setup-codex.md` / `docs/setup-claude-code.md` yourself the first time.
- The Linux path requires a running Secret Service provider (GNOME Keyring, KWallet via ksecrets, or similar) — typical on a desktop session, often absent on headless/server Linux. This kit doesn't cover a headless-Linux credential backend.
- Two known Claude Code behaviors (the `switchModelsOnFlag` persistence risk and the `/model` picker listing native models) were confirmed on the versions in use at the time of writing and should be re-checked, not assumed permanent.

## Sources

See [docs/sources.md](docs/sources.md) for the vendor/tool documentation this kit relies on, what was independently verified versus taken from docs, and the evidence boundary for the workload figures above.

## License

[MIT](LICENSE).

## Changes since the first version of this kit

See [CHANGELOG.md](CHANGELOG.md).
