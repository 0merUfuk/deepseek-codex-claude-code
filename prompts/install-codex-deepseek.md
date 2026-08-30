# Agent prompt: install an isolated Codex + DeepSeek profile

Configure my existing Codex CLI installation so DeepSeek is available through an explicit `deepseek` profile while normal `codex` remains unchanged. This works on macOS, Linux, and Windows — detect which one you're on first and follow that branch throughout; don't mix steps from different platforms.

## Preconditions — check these before doing anything else

- Codex CLI is already installed (`codex --version` succeeds). This prompt adds DeepSeek to an existing install; it does not install Codex itself. If it's missing, stop and tell me to install Codex first rather than trying to work around it.
- I already have a DeepSeek API key. This prompt cannot obtain one for me — if I don't have one, stop and tell me where to get it (see `docs/sources.md` in this repo for the current DeepSeek docs links) rather than guessing or fabricating a placeholder.
- You have real local shell, filesystem, and OS secret-store access (macOS Keychain / Linux Secret Service / Windows Credential Manager) on the machine where Codex is installed. If you're running in a sandboxed or remote environment without that access, stop and say so — this setup cannot complete without it, and pretending otherwise would produce a config that looks right but doesn't work.

## Non-negotiable requirements

- Preserve the current normal `codex` behavior.
- Do not edit `~/.codex/config.toml` unless current installed Codex behavior proves profile-v2 is unavailable and you stop to explain the trade-off first.
- Prefer current Codex profile-v2: `$CODEX_HOME/deepseek.config.toml`, selected with `codex --profile deepseek`.
- Do not store my DeepSeek API key in TOML, JSON, source files, shell/command history, screenshots, logs, prompts, or the repository.
- Store the credential in the OS's native secret store under a service/target name dedicated to this tool, e.g. `deepseek-api-codex` — macOS Keychain, the Linux Secret Service (via `secret-tool`), or Windows Credential Manager (via the bundled `scripts/windows/deepseek-credential-token.ps1 -Store`). If I also run a DeepSeek launcher for Claude Code, use a **different DeepSeek API key** under its own name — never the same key under two names (see README "Why two distinct DeepSeek API keys" for why).
- Whatever the OS, the credential-store step must be run by me directly in an interactive terminal (or, on Windows, via the bundled store script's own secure prompt) — never type or paste the raw key into a command you run on my behalf, and never accept it as a prompt argument, so you never see or handle the plaintext key.
- Prefer current Codex command-backed custom-provider auth so the token does not need to be exported into the Codex process environment.
- Create a dedicated launcher `codex-deepseek` (macOS/Linux: a `codex-deepseek` shell script; Windows: `codex-deepseek.ps1`).
- Treat current official DeepSeek docs and the installed Codex schema/source as authoritative over this prompt for version-sensitive fields. Where docs and the installed binary disagree, or a doc claim is surprising, verify against the installed binary/source before trusting it (e.g. `strings` the Codex binary for the relevant struct/field names) rather than taking either source on faith.
- Never claim success until both normal and DeepSeek paths have been verified end-to-end with a real request.
- **macOS and Linux are verified working designs; the Windows path is a reasoned but unverified port** (no Windows machine was available to test it while this kit was written). If you're on Windows, say so explicitly when you report completion, and be more conservative about claiming something works versus something merely ran without an error.

## Before changing anything

1. Detect the OS (`uname -s` on macOS/Linux; `$PSVersionTable.Platform` or `$env:OS` on Windows) and commit to that platform's branch for the rest of this task.
2. Inspect `codex --version` and the current base config without printing secrets.
3. Confirm current `--profile` semantics for the installed Codex version.
4. Read the current DeepSeek Codex integration page and current model catalog.
5. Confirm the installed Codex version satisfies the current model-catalog minimum version.
6. Check whether `~/.codex/deepseek.config.toml`, a DeepSeek credential helper, or `codex-deepseek` already exists; reconcile deliberately rather than overwriting blindly. If a credential already exists under some other service/target name, prefer renaming/copying it to the convention above over discarding a working key.
7. State the intended files and rollback path.

## Desired architecture

```text
codex
  -> existing base configuration

codex-deepseek
  -> codex --profile deepseek
  -> ~/.codex/deepseek.config.toml
  -> model_providers.deepseek
  -> command-backed auth helper
  -> OS secret store, service/target "deepseek-api-codex"
     (macOS Keychain / Linux Secret Service / Windows Credential Manager)
  -> DeepSeek Responses API
```

## Credential helper

**macOS / Linux:** copy `scripts/deepseek-credential-token` from this repository to `~/.local/bin/deepseek-credential-token` **verbatim — do not rewrite it from the description below.** The checked-in script is already tested; regenerating your own from this spec risks missing a hardening detail (trailing-newline handling, treating an empty-but-present credential as an error, etc.). Only write a new one from the spec below if the repository file is genuinely missing.

It takes a service name as its one argument and returns the credential value for:

- service: the argument given (e.g. `deepseek-api-codex`)
- account: current OS user

It auto-detects macOS (`security find-generic-password`) vs. Linux (`secret-tool lookup`), never logs or decorates stdout, and never appends a trailing newline to the token, because Codex uses stdout as the bearer token. Errors go to stderr. An empty (but present) credential is an error, not a silent empty token.

**Windows:** copy `scripts/windows/deepseek-credential-token.ps1` from this repo **verbatim** — same rule as above, only write an equivalent if it's missing. It reads a generic credential from Windows Credential Manager via `advapi32.dll`'s `CredRead`, with the same stdout/stderr contract as above, and its `-Store` mode writes credentials via `CredWrite` after a hidden `Read-Host -AsSecureString` prompt so the key is never on the command line or in history.

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
command = "deepseek-credential-token"
args = ["deepseek-api-codex"]
```

On Windows, `command`/`args` instead need to invoke PowerShell with the helper script's path, e.g. `command = "powershell"`, `args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "<absolute path>\deepseek-credential-token.ps1", "deepseek-api-codex"]` — **this specific form is unverified**; confirm empirically that your installed Codex version on Windows actually invokes it this way (it may need a different quoting or invocation style) before trusting it.

If the current installed schema differs, adapt to the current schema and explain the difference.

**Path handling — verify, don't assume.** `auth.command` is invoked directly, not through a shell: a `~/...` path there is NOT tilde-expanded (reference the helper by bare name on `PATH`, or use an absolute path). `model_catalog_json` IS tilde-expanded, confirmed on macOS only. Confirm both empirically for your platform (point `model_catalog_json` at a nonexistent path and check Codex errors on load) rather than trusting this note.

Only use `model_reasoning_effort` values the model catalog actually declares for the selected model (check `supported_reasoning_levels` in the catalog file) — some Codex-native tiers (e.g. `xhigh`) are not necessarily valid for a third-party model catalog entry.

## Model catalog

Use the current official DeepSeek Codex `models.json`; do not reuse a stale checked-in copy. Save it separately as `~/.codex/deepseek.models.json` and validate the JSON before use.

Fetch DeepSeek's official one-line setup script — `https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh` (also in this repo's `docs/setup-codex.md`; re-check it's still current, vendor URLs change) — as raw bytes with `curl` (or `Invoke-WebRequest` on Windows), inspect it as **plain text** (do not execute it), and extract the `models.json` heredoc it writes.

**Provenance caution.** If you instead fetch the catalog through a web-fetch tool that summarizes/paraphrases page content via an intermediate model, treat the result as unverified — a summarizing pass can hallucinate or reconstruct plausible-looking JSON rather than reproduce it byte-exact, especially for large files. The raw setup script above is the more reliable source precisely because it skips that step. If a catalog entry contains something unexpected for a model-metadata file (e.g. a large embedded free-text instructions block), don't assume it's a hallucination or an injection without checking — verify it against a second, independently-fetched raw source before trusting or discarding it either way.

## Launcher

**macOS / Linux:** copy `scripts/codex-deepseek` from this repository to `~/.local/bin/codex-deepseek` **verbatim — do not rewrite it.** Only write a new one from the spec below if the repository file is genuinely missing. It:

1. verifies `codex` exists;
2. verifies the credential helper exists (on PATH) and the `deepseek-api-codex` credential is readable without printing it;
3. executes `codex --profile deepseek "$@"`;
4. does not modify the parent shell environment.

**Windows:** copy `scripts/windows/codex-deepseek.ps1` **verbatim** — same rule as above. It has the same four properties, using `$args` in place of `"$@"` and PowerShell's own command-existence checks (`Get-Command`) in place of `command -v`.

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
