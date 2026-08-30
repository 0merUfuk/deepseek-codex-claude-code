# Sources and verification date

Last verified: **2026-08-30** (macOS), **2026-08-31** (Windows).

Provider/tool integrations change quickly. Re-check these sources before installation or publication.

## DeepSeek

- Codex integration: https://api-docs.deepseek.com/quick_start/agent_integrations/codex/
- Claude Code integration: https://api-docs.deepseek.com/quick_start/agent_integrations/claude_code/
- Models & pricing: https://api-docs.deepseek.com/quick_start/pricing/
- Anthropic-compatible API guide: https://api-docs.deepseek.com/guides/anthropic_api/

**V4 Pro works fine with Codex's Responses API.** DeepSeek's official Codex model catalog (`~/.codex/deepseek.models.json`, fetched via their own setup script — see below) marks `deepseek-v4-pro` `supported_in_api: true` with the same `low`/`high`/`max` reasoning-effort levels as `deepseek-v4-flash`, and it's been used successfully through this kit's Codex profile. This kit's example config defaults to `deepseek-v4-flash` as a choice, not a workaround — swap `model = "deepseek-v4-pro"` in `~/.codex/deepseek.config.toml` if you want the larger model.

## OpenAI Codex

- Codex docs: https://developers.openai.com/codex/
- Codex config reference: https://developers.openai.com/codex/config-reference/
- Current source verification used for this kit: https://github.com/openai/codex

Specific current-source behaviors verified while preparing this package:

- CLI `--profile <name>` layers `$CODEX_HOME/<name>.config.toml` over the base user config.
- custom model providers support the Responses wire API.
- custom providers support command-backed bearer-token authentication; the command's trimmed stdout is used as the token and cached in memory. **Verified two ways, not just from docs**: the installed `codex` binary (0.150.1) was inspected directly (`strings` over the executable) and its config schema does define a `ModelProviderAuthInfo { command, args, timeout }` struct, confirming the feature exists in the actual shipped binary, not only in documentation.
- `model_catalog_json` path values ARE tilde-expanded by the config loader; `auth.command` values are NOT (it's invoked via `execvp`, no shell in between). Verified empirically by deliberately pointing each field at a broken path and observing the failure mode, not assumed from either vendor's docs.

## Claude Code

- Settings: https://code.claude.com/docs/en/settings
- Environment variables: https://code.claude.com/docs/en/env-vars
- CLI reference: https://code.claude.com/docs/en/cli-reference

The Claude launcher uses `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` when supported so provider credentials are stripped from Bash commands, hooks, and MCP subprocesses.

The `modelPicker` / `replaceBuiltInOptions` setting used to hide native models from `/model` while under DeepSeek was found by inspecting the installed Claude Code binary's embedded settings-schema strings, not from published docs at the time of writing — re-check current official settings documentation, since this may since have been documented or changed shape.

The reason to hide native models isn't that DeepSeek necessarily rejects a native model name outright: DeepSeek's Anthropic-compatible layer currently maps Claude-style model names onto DeepSeek models, so an accidental native-model selection could be silently served by a different DeepSeek model rather than failing loudly. Hiding the picker keeps the user-facing model choice and the model actually served by the provider from silently diverging — re-verify this mapping behavior against current DeepSeek docs before relying on either outcome (clean failure vs. silent remap).

**The `[1m]` model-name suffix is real, verified by inspecting an actual outgoing request — an earlier version of this kit got this wrong.** A previous pass assumed `deepseek-v4-pro[1m]` (as shown in DeepSeek's docs) was doc-page formatting bleeding into a code block, and stripped it in the launcher. That was based on an AI web-fetch tool's paraphrase of the doc page, not on checking what Claude Code actually does with the string — and it was wrong. Re-verified two ways: (1) the installed Claude Code binary's own code defines an alias list including `sonnet[1m]`, `opus[1m]`, `fable[1m]` (no `haiku[1m]`), plus explicit suffix-strip functions; (2) `ANTHROPIC_LOG=debug` on a live request showed the literal env var value `deepseek-v4-pro[1m]` reduced to `model: "deepseek-v4-pro"` on the wire, with `"anthropic-beta": "...,context-1m-2025-08-07,..."` added to the request headers as a direct result of the suffix being present. Removing the suffix (the earlier, wrong fix) makes Claude Code assume a 200,000-token context window for the model instead of its real ~1,048,576 — confirmed by the exact text of Claude Code's own "unrecognized model" warning, which states the assumed window explicitly. Lesson: an AI web-fetch tool's summary of what a doc page says is not evidence for what a client actually does with a value copied from that page — check the wire, not the paraphrase, and check it a second way independent of a summarizing pass.

**A model-alias resolution was observed persisting into normal `~/.claude/settings.json`, unprompted.** During testing, a `claude-deepseek` run left `deepseek-v4-flash` (the launcher's Haiku/subagent-tier alias, not the primary model) written into the *normal*, non-DeepSeek `~/.claude/settings.json`'s `"model"` field — so a subsequent plain `claude` invocation tried to use it against the real Anthropic API and failed outright. It did not reproduce on every run (three clean runs afterward showed no recurrence), which points to an internal/background alias resolution as the trigger rather than the interactive model selection itself. The pre-existing `switchModelsOnFlag: true` setting (found in `~/.claude/settings.json`, not something this kit set) is the most likely mechanism — it's documented in the binary's own settings schema as governing whether a model change persists as the new default. Forcing `"switchModelsOnFlag":false` in the launcher's session-scoped `--settings` payload stopped it across repeated test runs. Treat this as: fixed as far as it's been tested, not proven impossible — check `settings.json`'s `model` field after any real use, not just once during setup.

## A note on verifying vendor-provided content, not just vendor claims

While preparing this kit, a DeepSeek Codex model-catalog fetch (via an AI agent's web-fetch tool) returned a `models.json` where each model entry contained a large embedded free-text block resembling a full assistant system prompt. That looked, at first pass, like it could be a hallucination introduced by the fetch tool's own summarization step, or a prompt-injection risk if installed as-is. It turned out to be genuine — confirmed by fetching DeepSeek's official setup script directly with `curl` and reading it as plain, un-summarized text, where the identical content appeared in a `write_models_json()` heredoc. The lesson generalizes: when a fetch tool paraphrases or summarizes a large vendor artifact instead of returning it byte-exact, verify surprising content against a second, rawer source before trusting or discarding it — don't do either on a single pass through a summarizer.

## Cross-platform status (Linux, Windows)

Originally, everything under "OpenAI Codex" and "Claude Code" above was verified against macOS behavior specifically. Linux and Windows were then added as a reasoned port from well-documented, standard OS APIs (Secret Service; Windows Credential Manager via `advapi32.dll`), without a machine available to test either at the time.

**Windows is now verified end to end (2026-08-31)**, independently, by someone other than the author — both the Codex and Claude Code paths, with real DeepSeek dashboard usage confirming requests actually reached the provider, not just that the launchers ran without erroring. That resolves what was previously unverified there: `model_catalog_json` tilde-expansion, whether Codex's `auth.command` + `args` array actually invokes `powershell.exe` with a script path the way the config example assumes, and whether the `[1m]` suffix behaves the same on the wire — all confirmed working as documented.

**Linux remains unverified.** The Secret Service path (`secret-tool`) is still a reasoned port from documented APIs, not run on a Linux machine while preparing this kit. Run the verification steps in `docs/setup-codex.md` and `docs/setup-claude-code.md` yourself the first time on Linux, the same way macOS and Windows were verified rather than assumed from docs.

## Evidence boundary

The workload numbers in this repository come from the author's own DeepSeek dashboard screenshots, not from the documentation above — see the README's "Evidence boundary" for the figures and what they don't cover.

**Anecdotal note, not a benchmark.** During this hands-on use, DeepSeek's prompt caching subjectively felt unusually effective — repeat-request cost noticeably lower than the author's usual experience with other providers. This is an unverified impression, not a measurement: no cache-hit ratio was captured, and no other provider's numbers are attached for comparison. Don't cite it as a pricing or caching-efficiency claim; if that comparison is ever run properly, it belongs with real numbers, not here.
