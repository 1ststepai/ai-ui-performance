# AI UI Performance

An independent MIT-licensed Windows skill/plugin by 1ststep.ai. Check resource pressure and apply a reversible CPU priority profile for AI interfaces. Not affiliated with OpenAI, Anthropic, Google, xAI, Cursor or browser vendors.

**This changes scheduling preference under CPU contention. It does not reduce RAM, redesign an app, or speed cloud inference. No measured latency improvement is claimed.** Commands run on demand; no daemon, telemetry, scheduled task or model call is installed.

| Interface | Supported Windows route |
| --- | --- |
| Codex | Installed OpenAI.Codex MSIX with the expected publisher |
| Claude Desktop | Anthropic MSIX or a signed executable at the supported classic path |
| Cursor | Signed Anysphere executable at supported per-user/Program Files paths |
| Gemini and Grok web/PWA | Explicit shared Chrome, Edge or Brave profile |
| Other browser AI UIs | Same shared browser profile |
| Claude Code and terminal agents | Excluded |

Paths are enumerated in `skills/ai-ui-performance/scripts/Apps.ps1`. Missing, unsigned, relocated or unexpected installations are skipped. macOS/Linux and other browsers are unsupported in this version. Browser mode affects unrelated tabs too; isolated tab priority is not claimed.

## Install

```powershell
git clone https://github.com/1ststepai/ai-ui-performance.git
cd ai-ui-performance
codex plugin marketplace add .
```

Install **AI UI Performance** from that marketplace in your desktop app's Plugins directory. CLI commands vary by version; see [OpenAI packaging](https://developers.openai.com/plugins/build/plugins). A GitHub marketplace is separate from the universal public Plugins Directory; review approval is required for the latter.

Alternatively, copy both skill folders under `skills/` into a user skill directory your Codex version loads, such as `~/.codex/skills` or `~/.agents/skills`. Check before overwriting existing skills. Regular folders work around builds that skip Windows junctions. Keep both skills together to support the legacy entry point.

In a new chat:

> Use $ai-ui-performance to check my AI apps and optimize desktop UI responsiveness.

Ask to restore the profile to undo. `$codex-performance` still targets Codex only. This skill runs inside Codex; it manages eligible UI processes for the other apps without adding extensions to those apps.

## Direct commands

Windows PowerShell 5.1 is required; no additional packages or API keys are needed.

```powershell
$tool = '.\skills\ai-ui-performance\scripts\AI-UI-Performance.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Speed -App Desktop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Restore -App All

# Explicit shared-browser profile for Gemini/Grok and other web UIs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Speed -App Browsers -IncludeBrowsers
```

`-App Codex`, `Claude` or `Cursor` targets one desktop app. `Gemini` and `Grok` select shared supported browsers, not individual tabs. Speed with `All`, `Browsers`, `Gemini` or `Grok` requires `-IncludeBrowsers`. Restore changes only recorded processes in its chosen app scope. Add `-WhatIf` to preview without profile writes.

Double-click `AI-UI-Speed.cmd` for a desktop-only apply or `Codex-Speed.cmd` for Codex only. If no verified running UI is found, Speed returns an error instead of broadening the target. Access errors are reported; do not disable security protections to force a change.

## Safety and limits

Only main and currently Normal renderer processes become AboveNormal. Idle renderers, GPU workers, utilities, CLI agents and other executables are excluded. Installed MSIX publisher identity or known paths with valid Authenticode publisher signatures establish eligibility; a process name alone never authorizes changes.

The private journal remains in `~/.codex/performance` for compatibility with the earlier Codex tool. It records original priority before mutation. Restore checks full path, process ID, UTC start time and expected applied priority; later app/tool changes are skipped. Atomic replacement and an exclusive lock protect the journal. Failed changes retain undo records; corrupt state stops writes. Profiles reset when processes restart, so reapply on demand.

Working sets may include shared memory; their sum is not unique allocated RAM. Browser mode can include non-AI and remote desktop tabs. No URLs/chats are inspected, no processes are killed, and no services, network, model, billing, security or graphics settings are changed. There is no memory trimming or High/Realtime mode.

## Validation and contribution

```powershell
powershell.exe -NoProfile -File .\tests\Test-Performance.ps1
```

Tests cover identity, PID reuse, exited processes, role/priority exclusions, scoped restore, repeated apply, denied mutations, journal failure/corruption, locking, and a disposable real child priority cycle. Fixtures validate app selection; they do not prove testing every vendor UI. Tests never change actual AI apps.

See [privacy](PRIVACY.md), [security](SECURITY.md), and [MIT license](LICENSE). Private process inventories, machine receipts, coordinator state and undo journals are excluded from source and release packages.

Sources: [Microsoft priority API](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass), [OpenAI skills](https://learn.chatgpt.com/docs/build-skills), [OpenAI submission](https://developers.openai.com/plugins/deploy/submission).
