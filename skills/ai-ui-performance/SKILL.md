---
name: ai-ui-performance
description: Diagnose Windows AI UI resource pressure and explicitly test experimental reversible CPU priority profiles. No repeatable UI benefit is demonstrated. Supports verified desktop apps and opt-in shared browsers; does not accelerate inference or reduce RAM.
---

# AI UI Performance

The current profile has not demonstrated a repeatable UI benefit in the built-in browser test. For a general lag complaint, diagnose with Check first. Do not automatically apply Speed as a proven fix. Use Speed only for an explicitly requested experiment or when applicable controlled measurement supports it. A user requirement for proven or guaranteed improvement is not satisfied by priority readback or safety tests. Restore experimental changes when no repeatable benefit is shown.

Run `scripts/AI-UI-Performance.ps1` relative to this skill with Windows PowerShell 5.1. Default `-Mode Check` is read-only: verified apps, process roles/priorities, available RAM, and large competing processes. Normal reports exclude process arguments, chat content, browser URLs, and credentials. Resource pressure suggests a bottleneck, not a proven cause of lag.

When optimization is requested, use `-Mode Speed -App Desktop`. This selects verified Codex, Claude Desktop and Cursor installations; Claude Code CLI helpers are excluded even when their executable shares a name. `-App Codex`, `Claude`, or `Cursor` targets one desktop app. Only main and currently Normal renderers become AboveNormal. Idle renderers, GPU workers, utilities, other executables and services stay unchanged.

Gemini/Grok web UIs, browser-hosted AI apps and PWAs use the shared browser profile. Explain that it affects eligible Chrome, Edge and Brave processes, including unrelated tabs and remote desktop tabs. Only apply when browser-wide optimization is requested: `-App Browsers -IncludeBrowsers` (or `Gemini`, `Grok`, or `All` with that flag). Never claim isolated tab control or inspect chat content. For ambiguous requests, check first and apply only the requested desktop scope.

Undo with `-Mode Restore -App <same target>`; `-App All` restores owned desktop and browser changes. Restore checks full executable path, process ID, UTC start time and expected applied priority. It skips stale identities and later app/tool priority changes. Private state stays in `~\.codex\performance` for compatibility with the original Codex tool. `-WhatIf` previews without profile writes. Report failures, skipped results and no-change outcomes accurately; verify with Check.

Profiles reset when processes restart. They change CPU scheduling preference, not RAM, UI code, network speed or cloud model latency. No measured speedup is promised. Never add background polling, memory trimming, High/Realtime priority, process termination, security changes or unsupported flags. This version supports Windows and the verified installation layouts in the README.
