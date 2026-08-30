# Isolated Codex CLI + DeepSeek setup (macOS, Linux, Windows)

This guide creates an **opt-in DeepSeek profile** for Codex CLI while leaving the normal `~/.codex/config.toml` untouched.

The important current Codex behavior is `--profile <name>`: it layers `$CODEX_HOME/<name>.config.toml` on top of the base user configuration. For the profile name `deepseek`, the file is:

```text
~/.codex/deepseek.config.toml
```

The public reproduction below also uses Codex's current command-backed provider authentication so the DeepSeek API key can stay in the OS's native secret store — macOS Keychain, the Linux Secret Service, or Windows Credential Manager — instead of being stored in TOML or inherited through the Codex process environment.

**Platform status:** the macOS path is verified end to end (see [docs/sources.md](sources.md)). The Linux and Windows paths follow the same design and use well-documented OS APIs, but have not been run on a Linux or Windows machine as part of preparing this kit — verify each step yourself the first time, the same way the macOS path was originally verified.

## 0. Preconditions

You should already have:

- Codex CLI installed and working normally;
- a DeepSeek API key;
- your OS's secret store available — macOS Keychain (built in), a Linux Secret Service provider (GNOME Keyring, KWallet via ksecrets, or similar — typical on a desktop session, often absent on headless/server Linux), or Windows Credential Manager (built in);
- a current Codex version compatible with DeepSeek's current model catalog.

Record the starting state before changing anything:

```bash
codex --version
```

Do not paste secrets into screenshots, commits, shell profiles, prompts, logs, or configuration files.

## 1. Store the DeepSeek key in your OS's secret store

Give it a service/target name dedicated to Codex, distinct from the Claude Code launcher's. Run this yourself in an interactive terminal so the key is never typed by an agent, written to shell/command history, or echoed to the screen.

**Why `deepseek-api-codex` and not a generic `deepseek-api`:** if you also set up the Claude Code launcher in this kit, it uses its own service name (`deepseek-api-claudecode`) — and, more importantly, its own distinct DeepSeek API key. It's the distinct keys, one per tool, that make DeepSeek dashboard usage attributable per tool and let you rotate one without touching the other. Storing the same key under two different service names would not give you either property.

### macOS

```bash
security add-generic-password -a "$USER" -s "deepseek-api-codex" -w -U
```

`security` prompts for the value directly — it won't be echoed or written to shell history.

### Linux

```bash
secret-tool store --label="DeepSeek API key (codex)" service deepseek-api-codex account "$USER"
```

`secret-tool` (package `libsecret-tools` on Debian/Ubuntu, `libsecret` on Fedora) prompts for the value on stdin without echoing it. Requires a running Secret Service provider — if `secret-tool` errors immediately, you likely don't have GNOME Keyring or KWallet's Secret Service integration running (common on headless/server Linux); this kit doesn't cover that case.

### Windows

```powershell
.\scripts\windows\deepseek-credential-token.ps1 -Store deepseek-api-codex
```

Prompts via `Read-Host -AsSecureString` (input hidden, never on the command line or in PowerShell history) and writes to Windows Credential Manager as a generic credential.

## 2. Install the credential helper

### macOS / Linux

Copy the helper into a directory on your `PATH`:

```bash
mkdir -p ~/.local/bin
cp scripts/deepseek-credential-token ~/.local/bin/deepseek-credential-token
chmod 700 ~/.local/bin/deepseek-credential-token
```

It does one thing: read a named credential from the OS secret store (macOS Keychain or Linux Secret Service, auto-detected) and write it to stdout for Codex's provider-auth process, with no trailing newline and no other output.

Verify only the exit status — do not print the token:

```bash
~/.local/bin/deepseek-credential-token deepseek-api-codex >/dev/null
```

### Windows

Copy `scripts\windows\deepseek-credential-token.ps1` next to wherever you'll keep `codex-deepseek.ps1` (e.g. `~/.codex/scripts/`) — `codex-deepseek.ps1` looks for it in the same directory as itself. Verify only the exit status:

```powershell
.\deepseek-credential-token.ps1 deepseek-api-codex | Out-Null
```

## 3. Install the current DeepSeek model catalog

DeepSeek's official Codex integration publishes a `models.json` catalog containing model metadata such as context limits, tool behavior, and reasoning levels.

**Get it as raw bytes, not through a summarizer.** If you're pulling this via an AI agent's web-fetch tool, that tool typically routes page content through an intermediate model to answer a prompt about it — for a large embedded JSON blob, that intermediate step can silently reconstruct a plausible-but-wrong version instead of reproducing it byte-for-byte. The most reliable source is usually DeepSeek's own one-line setup script (the one their docs tell you to `curl | bash`): fetch it with plain `curl` (or, on Windows, `Invoke-WebRequest`) to a local file, inspect it as **plain text** (do not execute it — the point here is only to read the embedded catalog, not to let the script rewrite your base config), and extract the JSON it writes.

```bash
curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh -o /tmp/deepseek-codex-setup.sh
# Read it — find the `models.json` heredoc and copy only that block out to
# ~/.codex/deepseek.models.json, then delete the script.
```

If a fetched catalog entry contains something you don't expect for a model-metadata file — for example a large embedded free-text "instructions" block — don't assume it's fabricated or malicious on sight, but don't trust it blindly either. Cross-check it against a second, independently-fetched raw source (the setup script above is a good second source) before deciding whether to use it. In this case that content turned out to be genuine: DeepSeek's catalog entries carry an `instructions_template`/`base_instructions` field that duplicates Codex's own default assistant persona, since Codex's schema expects third-party model-catalog entries to supply one.

Save the result to:

```text
~/.codex/deepseek.models.json
```

Validate the JSON before trusting it further:

```bash
python3 -m json.tool ~/.codex/deepseek.models.json >/dev/null
```

This kit intentionally does not freeze a provider-owned catalog that can become stale — re-fetch it periodically or when DeepSeek ships new models.

## 4. Create the isolated Codex profile

Copy the example:

```bash
cp config/deepseek.config.toml.example ~/.codex/deepseek.config.toml
```

The profile contains the DeepSeek model selection and custom provider definition:

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

On Windows, replace the `auth` block per the commented-out alternative in `config/deepseek.config.toml.example` — `command = "powershell"` with `args` pointing at `deepseek-credential-token.ps1`. That form is untested; verify it against your installed Codex version before relying on it.

The provider-auth command is a current Codex feature, confirmed present in the installed binary (its config schema defines a `ModelProviderAuthInfo { command, args, timeout }` struct — not just documented, but verifiable by inspecting the installed `codex` executable directly). Codex invokes the helper, trims its stdout, and uses that value as the bearer token. The token is cached in memory by Codex for the configured refresh interval rather than written into the profile.

If your installed Codex version predates command-backed provider auth, do **not** silently fall back to plaintext `experimental_bearer_token`. Update Codex, or deliberately choose a documented alternative after reviewing the security trade-off.

**Path handling gotcha, verified empirically on macOS:** `model_catalog_json = "~/..."` above IS tilde-expanded by Codex's config loader (confirmed by pointing it at a deliberately nonexistent path and observing a hard load error, rather than silent success). But `auth.command` is **not** — it's invoked directly via `execvp` (or the Windows equivalent), without a shell, so a `~/...` value there fails with "No such file or directory" even when the file exists. That's why the profile above references the helper by bare name (relying on it being on `PATH`) rather than by path. Don't assume both fields behave the same way, and don't assume this holds on Linux/Windows without checking — different Codex versions and platforms could change either behavior, so re-verify rather than trust this note indefinitely.

## 5. Install the launcher

### macOS / Linux

```bash
cp scripts/codex-deepseek ~/.local/bin/codex-deepseek
chmod 700 ~/.local/bin/codex-deepseek
```

### Windows

Copy `scripts\windows\codex-deepseek.ps1` next to `deepseek-credential-token.ps1` (step 2). Run it directly, or add that directory to your `PATH` / create a short function or alias for it in your PowerShell profile if you want a bare `codex-deepseek` command — that's a convenience choice, not something this kit prescribes.

The launcher performs preflight checks and then runs:

```bash
codex --profile deepseek
```

No DeepSeek secret is exported by the launcher.

## 6. Verify both paths

### Normal path

```bash
codex
```

Confirm the normal provider/model behavior is the same as before. Because the base `~/.codex/config.toml` was not changed, this path should remain unchanged.

### DeepSeek path

```bash
codex-deepseek
```

(On Windows: `.\codex-deepseek.ps1`.)

Confirm the startup/status information shows the intended DeepSeek model/provider. Then send one small non-sensitive request and verify that new usage appears in the DeepSeek dashboard.

Do not call the setup complete based only on a TOML file or UI label. Verify the actual provider path with a real request.

## 7. Session-history gotcha

DeepSeek documents that previous Codex sessions can appear missing after switching between official ChatGPT authentication and a third-party API provider. The sessions are grouped by login method; they are not necessarily deleted.

That behavior matters when comparing the normal and DeepSeek paths. Treat a missing history view as a visibility/auth-grouping issue first, not evidence of data loss.

## 8. Optional: extra caution for a third-party model

If you'd rather be conservative while you're still building trust in a model you haven't used before, two profile-only settings add friction without touching your base config:

```toml
approvals_reviewer = "user"

[features]
hooks = false
```

The first requires your own approval on risky actions instead of an automated reviewer; the second disables this session's hooks so a DeepSeek session can't trigger your normal automations. Both are commented out in `config/deepseek.config.toml.example` — uncomment if you want them.

## 9. Rollback

The profile-v2 design has a small rollback surface:

1. stop using `codex-deepseek`;
2. remove or archive `~/.codex/deepseek.config.toml`;
3. optionally remove `~/.codex/deepseek.models.json`;
4. optionally remove the helper scripts;
5. optionally delete the credential:

   **macOS:**
   ```bash
   security delete-generic-password -a "$USER" -s "deepseek-api-codex"
   ```

   **Linux:**
   ```bash
   secret-tool clear service deepseek-api-codex account "$USER"
   ```

   **Windows:**
   ```powershell
   cmdkey /delete:deepseek-api-codex
   ```

No restoration of `~/.codex/config.toml` is required because this setup does not edit it.

## Why not use DeepSeek's official installer?

The official DeepSeek installer is valid and convenient. It backs up and modifies the shared Codex configuration so DeepSeek becomes available across Codex clients.

This guide optimizes for a different property: **CLI-level opt-in isolation**. Normal `codex` stays on the base configuration; `codex-deepseek` explicitly layers the DeepSeek profile.
