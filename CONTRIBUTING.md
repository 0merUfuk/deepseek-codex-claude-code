# Contributing

This is a small reproduction kit — bash/PowerShell scripts and docs, no build step, no test suite. Keep contributions proportional to that.

## Most useful right now

- **Linux or Windows verification.** Those paths are a careful port from documented OS APIs but haven't been run end to end (see `docs/sources.md`). A report of what worked, what didn't, and on what OS/tool versions is genuinely useful — a PR fixing something you hit is even better.
- **Version-sensitive corrections.** DeepSeek, Codex, and Claude Code all move fast. If something in `docs/` no longer matches current behavior, say what changed and how you confirmed it (not just "docs say X now" — check the actual tool where you can).

## Making a change

1. Fork, branch, make a focused change.
2. If you're touching a script, actually run it — `bash -n` for syntax at minimum, a real invocation if you can.
3. If you're touching a claim in `docs/` (a "verified" statement, a behavior description), say how you checked it.
4. Open a PR describing what changed and why.

## Reporting an issue

Include your OS, the Codex/Claude Code version, and what you actually observed versus what the docs said would happen.

## Security

Don't open a public issue with a real API key or other credential in it, even redacted-looking. If you're reporting a credential-handling bug, describe the behavior instead.
