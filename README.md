# DeepSeek with Codex + Claude Code

> **Setting this up with an AI coding agent?** Point it at [`prompts/install-codex-deepseek.md`](prompts/install-codex-deepseek.md) and/or [`prompts/install-claude-deepseek.md`](prompts/install-claude-deepseek.md) and have it read and follow the file end to end — they're written as agent instructions, with verification gates and rollback steps built in. One step can't be automated on purpose: storing the DeepSeek API key is designed to require you, not the agent, typing it into a secure, non-echoing prompt — see "Security / credential isolation" below.

A reproducible macOS, Linux, and Windows kit for running DeepSeek through **Codex CLI** and **Claude Code** while keeping both normal tool paths unchanged: one provider, two harnesses, two protocol paths.

The two harnesses reach DeepSeek through different compatibility layers, and are not necessarily configured with the exact same model — Codex uses `deepseek-v4-flash`; Claude Code's launcher uses `deepseek-v4-pro[1m]` as its primary model and `deepseek-v4-flash` for its lighter tier. Don't read this kit as "same model, different harness" — a controlled comparison that holds the model constant across harnesses is future work, not something this kit already demonstrates.

```text
Codex       -> opt-in profile          -> Responses API             -> DeepSeek
Claude Code -> process-scoped override -> Anthropic-compatible API  -> DeepSeek
```

Both integrations are live and verified on macOS ([platform status](#current-compatibility)). Each harness uses its own DeepSeek API key, stored under a separate name in the OS's native secret store — macOS Keychain, Linux Secret Service, or Windows Credential Manager.

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

Verified **2026-08-30**, on macOS — Codex's Responses-API integration, command-backed provider auth, and Claude Code's `[1m]` context-window convention and `/model`-picker behavior all checked against the live tools, not just docs. Linux and Windows were added the same day from documented OS APIs (Secret Service, Windows Credential Manager) but haven't themselves been run — see [docs/sources.md](docs/sources.md) for exactly what's verified versus ported, and for anything version-sensitive before you install or republish from this kit.

## Known caveats

- Both `deepseek-v4-flash` and `deepseek-v4-pro` work on both harnesses, with the full `low`/`high`/`max` reasoning-effort range — this kit's example configs just default to specific choices per harness. Swap the model in `~/.codex/deepseek.config.toml` or via Claude Code's `/model` picker if you want the other one. Any comparison between the two harnesses should still control for which model each is actually using.
- Linux needs a running Secret Service provider (GNOME Keyring, KWallet, or similar) — usually there on a desktop session, often not on headless/server Linux, which this kit doesn't cover.

## Sources

See [docs/sources.md](docs/sources.md) for the vendor/tool documentation this kit relies on, what was independently verified versus taken from docs, and the evidence boundary for the workload figures above.

## License

[MIT](LICENSE).

## Changes since the first version of this kit

See [CHANGELOG.md](CHANGELOG.md).
