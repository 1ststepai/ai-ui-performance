# Security

The public command line accepts supported app targets, never arbitrary executable paths or process IDs. Eligible paths come from verified installed packages or known paths with valid publisher signatures. The utility does not kill processes or change security/network settings.

Use this repository's GitHub private vulnerability reporting when available. Do not publish credentials, chats or private journals. If private reporting is unavailable, open a content-free issue requesting a private channel first.

Supported release: latest 0.2.x. Changed vendor packaging/signatures can make an installation unsupported until reviewed; the tool skips it rather than guessing.
