# Feature Landscape

**Domain:** YunoHost native app package wrapping LibreChat
**Researched:** 2026-09-18

## Table Stakes

Features users expect from a YunoHost app package. Missing = package feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `yunohost app install librechat` works end-to-end | Core YNH value proposition | High | Complex multi-step: source download, npm build, MongoDB, Meilisearch, nginx, systemd |
| Working LibreChat web UI behind HTTPS | User can't use app without it | High | nginx must proxy WebSocket + SSE. YNH handles certs automatically. |
| `yunohost app upgrade librechat` works and preserves config | Required for catalog acceptance | High | Config merge (never overwrite). AUR lesson: user .env and librechat.yaml must survive upgrades |
| `yunohost app remove librechat` cleans up cleanly | Required for catalog acceptance | Medium | Must not remove shared MongoDB instance. Only namespaced cleanup. |
| `yunohost app backup librechat` produces consistent backup | Required for catalog acceptance | Medium | MongoDB via `ynh_mongo_dump_db`, not raw volume copy |
| `yunohost app restore librechat` works | Required for catalog acceptance | Medium | Must re-install Meilisearch binary during restore |
| App runs under dedicated system user ($app) | YNH security standard | Low | Handled by `[resources.system_user]` |
| Valid manifest.toml (packaging v2) | Required for YNH 11.1+ | Low | Schema-validated by YNH core |
| All major LLM providers configurable | LibreChat's core value | Low | Done upstream. Package just needs to expose config files. |

## Differentiators

Features that set this package apart from raw LibreChat installs.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| One-command install of LibreChat + MongoDB + Meilisearch | Target user runs YNH to avoid manual setup | High | Complex orchestration but is the whole point |
| Native (Docker-free) install on low-RAM devices | YNH audience runs Raspberry Pis, small VPSes | High | npm build is RAM-intensive; Meilisearch is lightweight |
| YNH-native backup/restore of all components | Single `yunohost backup create` captures everything | Medium | Mongodump + file backup + service state |
| Auto-updating source URLs via autoupdate strategy | Less maintainer burden | Low | `autoupdate.strategy = "latest_github_tag"` in manifest |
| nginx with correct WebSocket + SSE config OOTB | Many self-hosters get this wrong | Low | Config template handles upgrade headers and buffering |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| SSO/LDAP integration | LibreChat has its own auth system. YNH LDAP integration would require significant upstream changes. | Declare `sso = false`, `ldap = false` in manifest. |
| Docker-in-a-package | Project requirement is native install. Docker is contentious in YNH community. | Native build from source. |
| Multi-domain install | Single domain per install is sufficient for v1. Complexity of multi-domain isn't worth it. | Single domain + optional sub-path. |
| Config panel in YNH webadmin | LibreChat already has a config system (librechat.yaml). Wrapping in YNH config panel adds maintenance burden. | Document that users edit `.env` and `librechat.yaml` directly. |
| Database management UI | MongoDB admin is out of scope for LibreChat package. | User installs mongo-express separately if needed. |

## Feature Dependencies

```
Install flows:
  Source download → Source extraction → npm build → MongoDB setup → Meilisearch install → systemd → nginx

Backup flow:
  mongodump → File backup declaration

Restore flow:
  File restore → MongoDB restore → Meilisearch binary reinstall → nginx restore → systemd restore → Service start

Upgrade flow:
  Service stop → Source rebuild → Config merge → Service start
```

## MVP Recommendation

Prioritize:
1. Working `install` script (source build, MongoDB, nginx, systemd)
2. Working `remove` script (namespaced, safe for shared MongoDB)
3. Working `backup`/`restore` scripts (consistency critical)

Defer:
- Meilisearch integration: still build the install path, but if it causes issues, make it a documented optional step
- change_url script: most YNH apps ship this, but it's not critical for MVP

---
*Feature landscape for: LibreChat YunoHost Package*
*Researched: 2026-09-18*
