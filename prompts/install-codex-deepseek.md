# Agent prompt: install an isolated Codex + DeepSeek profile on macOS

Configure my existing Codex CLI installation so DeepSeek is available through an explicit `deepseek` profile while normal `codex` remains unchanged.

## Non-negotiable requirements

- Preserve the current normal `codex` behavior.
- Do not edit `~/.codex/config.toml` unless current installed Codex behavior proves profile-v2 is unavailable and you stop to explain the trade-off first.
- Prefer current Codex profile-v2: `$CODEX_HOME/deepseek.config.toml`, selected with `codex --profile deepseek`.
- Do not store my DeepSeek API key in TOML, JSON, source files, shell history, screenshots, logs, prompts, or the repository.
- Store the credential in macOS Keychain under a service name dedicated to this tool, e.g. `deepseek-api-codex`. If I also run a DeepSeek launcher for another coding agent (Claude Code, etc.), use a **different DeepSeek API key** for each tool, each under its own service name — do not store the same key under two service names. It's the distinct keys that keep per-tool usage attributable on the DeepSeek dashboard and let me rotate one credential without touching the other; separate service names alone do not provide that.
- Prefer current Codex command-backed custom-provider auth so the token does not need to be exported into the Codex process environment.
- Create a dedicated launcher `codex-deepseek`.
- Treat current official DeepSeek docs and the installed Codex schema/source as authoritative over this prompt for version-sensitive fields. Where docs and the installed binary disagree, or a doc claim is surprising, verify against the installed binary/source before trusting it (e.g. `strings` the Codex binary for the relevant struct/field names) rather than taking either source on faith.
- Never claim success until both normal and DeepSeek paths have been verified end-to-end with a real request.

## Before changing anything

1. Inspect `codex --version` and the current base config without printing secrets.
2. Confirm current `--profile` semantics for the installed Codex version.
3. Read the current DeepSeek Codex integration page and current model catalog.
4. Confirm the installed Codex version satisfies the current model-catalog minimum version.
5. Check whether `~/.codex/deepseek.config.toml`, a DeepSeek Keychain-token helper, or `codex-deepseek` already exists; reconcile deliberately rather than overwriting blindly. If a credential already exists under some other service name, prefer renaming/copying it to the convention above over discarding a working key.
6. State the intended files and rollback path.

## Desired architecture

```text
codex
  -> existing base configuration

codex-deepseek
  -> codex --profile deepseek
  -> ~/.codex/deepseek.config.toml
  -> model_providers.deepseek
  -> command-backed auth helper
  -> macOS Keychain service deepseek-api-codex
  -> DeepSeek Responses API
```

## Credential helper

Create `~/.local/bin/deepseek-keychain-token` that returns the Keychain value for:

- service: `deepseek-api-codex`
- account: current macOS user

It must never log or decorate stdout, and must not append a trailing newline to the token, because Codex uses stdout as the bearer token. Errors go to stderr. Treat an empty (but present) Keychain value as an error, not a silent empty token.

## Profile

Create `~/.codex/deepseek.config.toml` using current supported fields. At the time this prompt was written, the intended structure is:

```toml
model = "deepseek-v4-flash"
model_provider = "deepseek"
model_reasoning_effort = "high"
model_catalog_json = "~/.codex/deepseek.models.json"

[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com/"
wire_api = "responses"

[model_providers.deepseek.auth]
command = "deepseek-keychain-token"
```

If the current installed schema differs, adapt to the current schema and explain the difference.

**Path handling — verify, don't assume.** `auth.command` is invoked directly (`execvp`), not through a shell: a `~/...` path there will NOT be tilde-expanded and fails with "No such file or directory" even though the file exists. Reference the helper by bare name and keep it on `PATH`, or use a fully-qualified absolute path. `model_catalog_json`, by contrast, IS tilde-expanded by Codex's config loader. Confirm both behaviors empirically for the installed version (e.g. by deliberately pointing `model_catalog_json` at a nonexistent path and confirming Codex errors on load, rather than silently ignoring it) instead of trusting this note or vendor examples blindly — schema behavior can change between versions.

Only use `model_reasoning_effort` values the model catalog actually declares for the selected model (check `supported_reasoning_levels` in the catalog file) — some Codex-native tiers (e.g. `xhigh`) are not necessarily valid for a third-party model catalog entry.

## Model catalog

Use the current official DeepSeek Codex `models.json`; do not reuse a stale checked-in copy. Save it separately as `~/.codex/deepseek.models.json` and validate the JSON before use.

**Provenance caution.** If you fetch the catalog through a web-fetch tool that summarizes/paraphrases page content via an intermediate model, treat the result as unverified — a summarizing pass can hallucinate or reconstruct plausible-looking JSON rather than reproduce it byte-exact, especially for large files. Prefer a source you can read as raw, un-summarized bytes: the vendor's official one-line install script (fetched read-only with `curl`, inspected as plain text, **not executed**) is often a more reliable source for an embedded catalog than an HTML doc page rendered through a summarizer. If a catalog entry contains something unexpected for a model-metadata file (e.g. a large embedded free-text instructions block), don't assume it's a hallucination or an injection without checking — verify it against a second, independently-fetched raw source before trusting or discarding it either way.

## Launcher

Create `~/.local/bin/codex-deepseek` that:

1. verifies `codex` exists;
2. verifies the Keychain helper exists (on PATH) and the credential is readable without printing it;
3. executes `codex --profile deepseek "$@"`;
4. does not modify the parent shell environment.

## Verification gates

Do not report completion until:

1. normal `codex` still uses its pre-change path;
2. `codex-deepseek` launches successfully;
3. the intended DeepSeek model/provider is visible in Codex status/startup information;
4. a minimal non-sensitive request succeeds;
5. DeepSeek-side usage evidence confirms the request reached the provider when available;
6. the API key is absent from config, catalog, scripts, shell profile, Git diff, and command output;
7. rollback is documented and does not require restoring the base config.

If a gate fails, report the exact failure and leave normal Codex usable.
