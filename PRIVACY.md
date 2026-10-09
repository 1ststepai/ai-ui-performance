# 1ststep Desktop Profiles privacy policy

Effective date: October 9, 2026. Publisher: 1ststep.ai. This policy covers version 0.2.2 of the packaged on-demand desktop diagnostic and scheduling utility, including its compatibility skill. Earlier versions examined process command lines temporarily; version 0.2.2 no longer does so. It does not cover unreleased prototypes elsewhere in the repository.

## Information accessed and purpose

The utility reads device and software metadata: installed application names, package identities, versions, executable paths and signatures; process names, IDs, UTC start times, priorities and memory working sets; available RAM and the active Windows power plan. Paths and Windows errors can contain a local account name.

The utility checks whether a verified process owns a main desktop window to determine profile eligibility. It does not request or inspect process command lines or arguments. It does not request passwords, tokens, government identifiers, payment details or health records, or inspect chats, documents, browser history, cookies, screenshots or clipboard contents.

This information is used to show resource pressure, verify target executables, apply an explicitly requested profile and restore recorded changes. It is not used for advertising, behavioral profiling or identity tracking. No demonstrated UI speed improvement is promised.

## Recipients

The utility has no publisher endpoint, analytics collector, remote database or automatic diagnostic upload. Running it does not send process information or journals to 1ststep.ai.

Reports are printed to the terminal or invoking tool host. That host may display, retain, process or transmit output through its services and providers under its settings and privacy policy. Invoking the utility through an AI agent can make the diagnostic output available to that agent and its service. This utility does not control those recipients or their retention.

Windows may contact certificate services to validate executable signatures. GitHub and OpenAI separately handle downloads, installation and marketplace review under their own policies.

If you voluntarily post a support issue, its contents are available to GitHub, the publisher and readers of a public issue. Nothing is posted automatically. Do not submit credentials, sensitive personal information or unredacted logs in an issue.

## Retention

Discovery data remains in command memory until the command exits. The utility does not persist process inventories or diagnostic reports. Your terminal or invoking host may retain output under its own retention rules.

Local journal, backup and lock files reside in `~/.codex/performance`. The journal stores executable paths, process IDs, UTC start times and original/applied priorities. These files have no automatic expiry and remain until you delete them. Restore retires applicable current records; an earlier journal copy can still contain those records. No chat content or credentials are stored there.

The publisher maintains no separate store of runtime diagnostics. Voluntary support issues remain on GitHub until edited or removed through its controls, subject to GitHub's retention policy; the utility creates no additional support database.

## User controls

Check inspects resources without changing priorities or writing an undo journal. Speed requires an explicit request, and shared-browser profiles require an additional opt-in flag. Restore undoes owned changes. WhatIf previews profile actions without applying them.

Review and redact reports before sharing. You can delete local journal and backup files using normal file-management tools. Restore first if you want to undo active changes: deleting records removes the utility's ability to restore them. Priority changes otherwise reset when the affected process restarts.

Stop invoking the utility or remove its skills to stop its use. It installs no always-running service, scheduled task or automatic monitoring loop. Local files are subject to your operating system's account permissions.

## Questions and support

Contact the publisher through https://github.com/1ststepai/ai-ui-performance/issues for non-sensitive privacy questions. If private details are needed, post a content-free request for a private contact channel first. Host-service data handling questions also belong with the relevant host's support and privacy controls.
