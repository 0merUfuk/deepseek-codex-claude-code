# Changelog

## 2026-08-31 - Linux and Windows support, squashed history, agent-discovery callout

Extended the kit from macOS-only to macOS/Linux/Windows, and cleaned up the repository ahead of going public.

- **Cross-platform credential storage.** Replaced the macOS-only `scripts/deepseek-keychain-token` with `scripts/deepseek-credential-token`, a single parameterized helper (`deepseek-credential-token <service-name>`) shared by both harnesses that auto-detects macOS (Keychain via `security`) vs. Linux (Secret Service via `secret-tool`). Added a Windows PowerShell equivalent, `scripts/windows/deepseek-credential-token.ps1`, using Windows Credential Manager through direct `advapi32.dll` P/Invoke (`CredRead`/`CredWrite`) — no third-party module. Its `-Store` mode prompts via `Read-Host -AsSecureString` so the key is never on the command line or in PowerShell history, matching the security bar of the macOS/Linux `security`/`secret-tool` prompts.
- **Windows launchers.** Added `scripts/windows/codex-deepseek.ps1` and `scripts/windows/claude-deepseek.ps1`, functional ports of the existing bash launchers (process-scoped `$env:` assignments, same model-picker/`switchModelsOnFlag` hardening, same verification contract).
- **`config/deepseek.config.toml.example`** now shows both the macOS/Linux `auth.command`/`args` form and a commented-out Windows form (`command = "powershell"` invoking the `.ps1` helper).
- **`docs/setup-codex.md` and `docs/setup-claude-code.md`** rewritten with a macOS/Linux/Windows branch at every OS-sensitive step (credential storage, helper/launcher install location, rollback).
- **Both `prompts/install-*.md` agent prompts** now open by telling the agent to detect its OS and follow that branch throughout, and carry the platform-specific credential/launcher instructions needed to act on either OS without guessing.
- **Honesty about verification status:** the macOS path remains the only one verified end to end. Linux and Windows are a reasoned port built from standard, documented OS APIs, explicitly flagged as unverified everywhere it matters (README, both setup docs, both agent prompts, `docs/sources.md`) — not claimed as tested when it wasn't.
- **README**: added a top-of-file callout pointing an AI agent straight at `prompts/install-*.md` instead of leaving it to infer that from "Getting started"; repository-contents tree, security section, and known caveats updated for the new file layout and platform status.
- **Squashed git history.** The repository's two commits (the original publish, which included the full `publishing/` directory before it was migrated out, and the cleanup commit that removed it) were squashed into one clean commit before this repository is made public. Deleting `publishing/` in a later commit did not remove it from git history — anyone could have checked out the first commit and seen the private Personal PR content this migration was meant to keep out of the public repo. No secrets were in that history (checked before squashing), but the content itself (social drafts, planning doc) was exactly what was supposed to stay private. Low-risk to rewrite: only two commits ever existed, both unpushed-to-public, no collaborators or forks.

## 2026-08-30 (5) - split off Personal PR material, corrected attribution/model-mapping wording, added license

Prepared the repository for eventual public release by separating the engineering artifact from the content/publishing operation around it, and fixed several documentation claims that were imprecise or too strong.

- **Moved all publishing/content-planning material out of this repository.** Everything previously under `publishing/` (the publishing plan, all post drafts across platforms, the dashboard screenshot assets, the reproduction-guide PDF, and the unrun Post 3 comparison protocol) now lives in a separate private workspace. Migration was verified by file count (14/14) and MD5 hash of every file against the original before `publishing/` was deleted from this repository. This repository no longer contains any social-media strategy, drafts, or Personal PR planning.
- **Corrected the "distinct Keychain service names create attribution" claim, everywhere it appeared.** It's the two DeepSeek API keys being genuinely different that makes per-harness dashboard usage attributable and lets either be rotated independently — separate Keychain *service names* are just where each key is stored. Fixed in `README.md`, `docs/setup-codex.md`, `docs/setup-claude-code.md`, `prompts/install-codex-deepseek.md`, `prompts/install-claude-deepseek.md`, and the comments in `scripts/claude-deepseek` and `scripts/deepseek-keychain-token`.
- **Softened the Claude Code model-picker failure claim.** Previous wording implied selecting a native model while pointed at DeepSeek reliably fails. DeepSeek's Anthropic-compatible layer currently maps Claude-style model names onto its own models, so the more accurate (and arguably stronger) reason to hide the picker is to prevent a native selection from being silently served by a different DeepSeek model rather than erroring — keeping the user-facing model choice and the model actually served from silently diverging. Fixed in the same files as above plus `docs/sources.md`.
- **Recorded a DeepSeek documentation inconsistency about V4 Pro and the Responses API** in `docs/sources.md`. This kit uses V4 Flash for Codex and doesn't depend on the disputed behavior, but it's worth knowing about before changing the Codex model.
- **Corrected "same DeepSeek backend" framing where it described the already-built setup.** Codex and Claude Code are not necessarily configured with the same DeepSeek model (Codex: `deepseek-v4-flash`; Claude Code: `deepseek-v4-pro[1m]` primary / `deepseek-v4-flash` subagent tier). Reframed as "one provider, two harnesses, two protocol paths" in `README.md` and the migrated publishing drafts; left as forward-looking intent where it correctly described the *planned*, not-yet-run, model-held-constant experiment.
- Added `LICENSE` (MIT) and referenced it from `README.md`.
- Updated `README.md`'s repository-contents tree and added explicit "Security / credential isolation," "Known caveats," "Sources," and "License" sections; removed all references to `publishing/`.

## 2026-08-30 (4) - promoted Codex and Claude Code into one launch story

Reframed the kit from "Codex first, Claude Code later" into one shared DeepSeek project with two first-class harnesses and two different protocol paths.

- Renamed the public project recommendation to `deepseek-codex-claude-code`.
- Replaced the Codex-only Post 1 framing with an umbrella launch covering both Codex and Claude Code.
- Kept the evidence boundary explicit: 211.3M tokens / 1,244 requests / $1.67 belongs to the observed Codex workload only; Claude Code remains verified but numberless.
- Rebuilt the guide and carousel narrative around `Codex -> Responses API` versus `Claude Code -> Anthropic-compatible API`.
- Renamed the Post 1 folder, PDF, dashboard assets, and current planning references to match the shared positioning.
- Kept Post 2 as the Claude Code engineering deep dive and Post 3 blocked until the comparison experiment is run.

## 2026-08-30 (3) — retracted a wrong fix, found a real settings-corruption bug

Both driven by actually checking a context-window question rather than assuming the earlier pass had covered it.

**Retraction:** the (1) entry below says "`deepseek-v4-pro[1m]` → `deepseek-v4-pro`... confirmed by fetching the raw doc page content directly." That "confirmation" was a paraphrase from an AI web-fetch tool of what the doc page *says*, not a check of what Claude Code actually *does* with the value — and it was wrong. Re-verified properly this time, two independent ways: the installed Claude Code binary's own alias-handling code (`sonnet[1m]`/`opus[1m]`/`fable[1m]`, explicit suffix-strip functions), and `ANTHROPIC_LOG=debug` on a live request showing the suffix stripped before the wire but an `anthropic-beta: context-1m-2025-08-07` header added because of it. The suffix is real and load-bearing: without it, Claude Code assumes a 200,000-token context window for the model instead of its actual ~1,048,576, silently defeating `CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432`. All `[1m]` values restored in `scripts/claude-deepseek`, `docs/setup-claude-code.md`, `prompts/install-claude-deepseek.md`, `docs/sources.md`. See `docs/sources.md` for the full writeup and the generalized lesson.

**New finding:** during the same investigation, a `claude-deepseek` test run left `deepseek-v4-flash` written into the *normal* `~/.claude/settings.json`'s `model` field, which then broke plain `claude` (it tried to use that value against the real Anthropic API and failed). Root cause: `switchModelsOnFlag` — a pre-existing Claude Code setting, not something this kit set — appears to persist certain model-alias resolutions as the new global default, including from an internal/background alias, not just an explicit interactive selection. Fixed by forcing `"switchModelsOnFlag":false` in the launcher's session-scoped `--settings` payload; held across three repeated test runs afterward. Added as a checked step (not just a mentioned risk) in `docs/setup-claude-code.md` and as a verification gate in `prompts/install-claude-deepseek.md`.

## 2026-08-30 (2) — drafted Post 2 content, split content/ by post

`publishing/content/` was flat and Codex-only, even though the Claude Code path is now built and verified. Reorganized and filled the gap:

- The original Post 1 assets were initially organized as a Codex-only launch before the later shared-project reframing.
- `publishing/content/post-2-claude-code/` — new: `linkedin.md`, `threads.md`, `x.md`, `first-comment.md`. Grounded only in what was actually verified this round (architecture difference, the `[1m]` doc-rendering bug, the `/model`-picker native-model leak) — deliberately carries **no** cost/token figures, since no real workload has been run on this path the way there is for Codex. Don't backfill numbers into these drafts without a real dashboard result behind them.
- No Post 2 Instagram carousel drafted — there's no headline number to anchor one yet.
- `publishing/PUBLISHING_PLAN.md` updated: corrected paths for the Post 1 move, added an explicit Post 2 asset list and status note, and marked Post 3 as not-yet-run so nothing gets published against experiment results that don't exist.
- `README.md`'s directory tree updated to match.

## 2026-08-30 — reconciled kit with the live setup, restructured for maintainability

This kit had drifted from the actual working setup (both were built from the same original prompts, but the live setup went through several rounds of fixes the kit never received). This pass reconciles them and reorganizes the directory.

### Fixed (content bugs)

- `deepseek-v4-pro[1m]` → `deepseek-v4-pro` everywhere in the Claude Code path. The `[1m]` is DeepSeek's doc-page rendering of a context-window annotation, not part of the literal model ID; using it verbatim makes every request fail. Confirmed by fetching the raw doc page content directly instead of trusting a first paraphrase.
- Single shared Keychain service `deepseek-api` → two distinct services, `deepseek-api-codex` and `deepseek-api-claudecode`. Sharing one key made DeepSeek dashboard usage indistinguishable between the two tools and coupled their rotation. This was a deliberate decision made after using the setup for a while, not just a rename.
- `deepseek-keychain-token` now strips the trailing newline `security -w` normally includes, and treats a present-but-empty Keychain value as an error rather than returning an empty token silently.
- `codex-deepseek` and the config example no longer hardcode an absolute path to the Keychain helper. Discovered that Codex's `auth.command` is invoked via `execvp` (no shell), so a `~/...` path there is never tilde-expanded and fails with "No such file or directory" even when the file exists — the fix is to keep the helper on `PATH` and reference it by bare name. `model_catalog_json`, by contrast, IS tilde-expanded — verified empirically (deliberately broken path → hard load error), not assumed.
- `claude-deepseek` now hides Claude Code's native model catalog (Opus/Sonnet/Haiku/Fable) from `/model` for DeepSeek sessions, via a session-scoped `modelPicker` setting passed through `--settings`. Previously, native models were still selectable alongside the DeepSeek aliases and would silently misroute if picked.

### Added

- A documented caution about vendor-content provenance in `docs/sources.md`: a DeepSeek model-catalog fetch (through an AI web-fetch tool) returned what looked like an implausible/injected payload; it turned out to be genuine DeepSeek content, confirmed by re-fetching from the vendor's raw setup script instead of trusting a summarized paraphrase. Both prompts now instruct future agents to verify surprising vendor content against a second, rawer source rather than accept or reject it on one pass through a summarizer.
- Both `prompts/*.md` now bake in every lesson above as explicit instructions, not just as after-the-fact notes — the point of keeping these prompts is that someone else runs them fresh, so the fixes need to live in the instructions themselves.
- Optional hardening block in `config/deepseek.config.toml.example` (`approvals_reviewer`, `features.hooks`) for extra caution while trusting a new model provider.
- `.gitignore` (`.DS_Store`, common local/secret patterns).
- This changelog.

### Reorganized

- Marketing/content-plan material (`PUBLISHING_PLAN.md`, `content/`, `experiments/`, the reproduction-guide PDF, `assets/`) moved under `publishing/`, separate from the technical kit. Cloning the repo to actually set up DeepSeek no longer requires wading through post drafts.
- `SETUP_CODEX.md`, `SETUP_CLAUDE_CODE.md`, `SOURCES.md` moved into `docs/` (lowercased, hyphenated) to make room for future per-harness guides without cluttering the repo root.
- Removed `.DS_Store` from the tree.

## Earlier

Initial version of the kit, covering the Codex-only setup and workload numbers (211.3M tokens / 1,244 requests / $1.67).
