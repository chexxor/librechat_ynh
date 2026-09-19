---
status: complete
phase: 01-foundation-install
source: [01-foundation-install-01-SUMMARY.md, 01-foundation-install-02-SUMMARY.md, 01-foundation-install-03-SUMMARY.md]
started: 2026-09-18T00:00:00Z
updated: 2026-09-19T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Package installs on YunoHost
expected: `yunohost app install` completes without errors — tarball downloaded and sha256-verified, MongoDB 7.0 installed, LibreChat built, Meilisearch binary downloaded, admin user created, success email with admin password sent
result: skipped
reason: Package not yet finished/pushed to GitHub repo — needs a real YunoHost server and published package before live install can be tested

### 2. Web UI accessible
expected: Browse to `https://<domain>/librechat` (or bare domain if installed at root) — LibreChat login page renders with HTTPS, no nginx errors
result: skipped
reason: Requires a live YunoHost server with the published package — user not installing LibreChat on this machine

### 3. Admin login works
expected: Log in with the admin email chosen at install and the password from the email/terminal — dashboard loads (chat UI, not an error)
result: skipped
reason: Requires a live YunoHost server

### 4. Services running after reboot
expected: `systemctl status librechat libremeilisearch` (or equivalent) shows both services active; a server reboot brings both back up automatically; MongoDB accepts connections
result: skipped
reason: Requires a live YunoHost server

### 5. Multi-instance blocked
expected: Attempting to install a second instance of the app fails with a clear message (multi_instance=false)
result: skipped
reason: Requires a live YunoHost server

### 6. Secrets not world-readable
expected: `/var/www/<app>/librechat.env` is chmod 600 owned by the app user; JWT/DB/Meili secrets inside match what services actually use (services run correctly with them)
result: skipped
reason: Requires a live YunoHost server

## Summary

total: 6
passed: 0
issues: 0
pending: 0
skipped: 6

## Gaps

[none yet]
