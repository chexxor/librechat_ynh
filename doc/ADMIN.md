# Admin Documentation

## Configuring LLM providers

By default, no LLM provider is configured. Edit `librechat.yaml` (at `<install_dir>/librechat.yaml`, e.g. `/var/www/librechat/librechat.yaml`) and uncomment the provider blocks for OpenAI, Anthropic, Ollama, and/or OpenRouter, adding your API keys. This file is preserved on upgrade.

## Admin account

During install, an admin user is created with the email you provided and a random password. The password is:

- shown at the end of the install output,
- emailed to the admin email address.

Change it in LibreChat account settings after first login.

## User management

Log in with the admin account, then use LibreChat's built-in admin panel at `/admin` to create users, reset passwords, or change roles. Registrations are closed by default (`ALLOW_REGISTRATION=false`).

If you want open registration, set `ALLOW_REGISTRATION=true` in `librechat.env` and restart the service (`systemctl restart librechat`).

## MongoDB and Meilisearch

- MongoDB runs as the system-wide `mongod` service, shared per YunoHost conventions. This app's database is namespaced (`<app>` database/user). Never drop MongoDB globally — all apps use it.
- Meilisearch runs as the `meilisearch` service, one instance per app install, bound to 127.0.0.1:7700 with a per-app master key.

## Enabling search

Search (Meilisearch) is disabled by default. To enable it:

1. Set `SEARCH=true` and confirm `MEILI_MASTER_KEY` is set in `librechat.env` (both at `<install_dir>/librechat.env`).
2. Restart the service: `systemctl restart librechat`.

## Logs

Service logs are available under `/var/log/librechat/` (also accessible via `journalctl -u librechat`). Meilisearch logs are at `/var/log/meilisearch/`.
