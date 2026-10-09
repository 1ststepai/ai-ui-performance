# Privacy

AI UI Performance runs locally when invoked. The utility sends no telemetry, process information, chats, URLs, credentials or files to its publisher or any endpoint.

It reads installed app identity, paths/signatures, process IDs, UTC start times, priorities, memory working sets, available RAM and the active Windows power plan. Process arguments are examined internally only to classify main, renderer and utility roles. Normal reports contain process/app names, counts and priority results, not arguments. Windows errors may include local paths.

A private undo journal, backup and lock in `~\.codex\performance` store executable identity and original/applied priorities. No chats, prompts, credentials or browser content are stored there.

Your AI host handles tool output under its own policies/settings. Windows may contact certificate services for signature validation; that is OS validation, not plugin telemetry. GitHub and OpenAI handle downloads and marketplace review under their own policies.

Review reports before sharing them. Do not post private journals, credentials or unredacted logs to issues. Restore active changes before deleting their undo records if you want to revert the profile.
