# Roadmap: LibreChat YunoHost Package

## Overview

A YunoHost native app package that installs LibreChat — a free, open-source, multi-provider LLM chat UI — with full lifecycle management. The journey starts with a working install (the highest-risk phase), then adds safe remove and backup/restore, and finally delivers config-preserving upgrades. Each phase builds on the previous one, converging on a YunoHost-catalog-ready package.

## Phases

- [ ] **Phase 1: Foundation + Install** — `yunohost app install librechat` works end-to-end with all services (MongoDB, Meilisearch, nginx, systemd) and provider templates
- [ ] **Phase 2: Remove + Backup/Restore** — Safe lifecycle management: clean remove, consistent MongoDB-dump backups, full state restore
- [ ] **Phase 3: Upgrade** — Config-preserving upgrade that rebuilds source, merges user settings, and never clobbers data

## Phase Details

### Phase 1: Foundation + Install
**Goal**: A one-command `yunohost app install librechat` produces a working, reachable LibreChat web UI behind HTTPS with all backing services, provider templates, and install questions.
**Depends on**: Nothing (first phase)
**Requirements**: SKEL-01, SKEL-02, SKEL-03, SKEL-04, SKEL-05, INST-01, INST-02, INST-03, INST-04, INST-05, INST-06, INST-07, INST-08, INST-09, INST-10, CONF-01, CONF-02, CONF-03, CONF-04
**Success Criteria** (what must be TRUE):
  1. `yunohost app install librechat` completes without errors and returns a reachable HTTPS URL
  2. LibreChat web UI is accessible at the app domain with valid HTTPS (Let's Encrypt)
  3. Chat messages stream correctly (WebSocket + SSE work through nginx proxy)
  4. An initial admin user exists and can log in (created via install with admin email from install question)
  5. `librechat.env` and `librechat.yaml` template files exist with provider configuration placeholders for OpenAI, Anthropic, Ollama, and OpenRouter
**Plans**: TBD

Plans:
- *(to be refined during planning)*

### Phase 2: Remove + Backup/Restore
**Goal**: `yunohost app remove`, `yunohost app backup`, and `yunohost app restore` all work correctly — remove is safe for shared MongoDB, backup produces consistent snapshots, restore fully recovers the app.
**Depends on**: Phase 1 (must have working install to define the service layout)
**Requirements**: RMV-01, RMV-02, RMV-03, RMV-04, RMV-05, BACK-01, BACK-02, BACK-03, BACK-04, BACK-05
**Success Criteria** (what must be TRUE):
  1. `yunohost app remove librechat` stops all services, removes app data, and cleans up the namespaced MongoDB database without affecting other MongoDB-using apps on the same server
  2. `yunohost app backup librechat` produces a consistent backup archive with MongoDB dump (`mongodump`), app config, and Meilisearch data
  3. `yunohost app restore librechat` from a backup archive fully restores the app — MongoDB data, config, Meilisearch, nginx config, and service state — resulting in a working LibreChat UI
  4. Back-to-back backup and restore round-trips without data loss (chat history and user accounts preserved)
**Plans**: TBD

Plans:
- *(to be refined during planning)*

### Phase 3: Upgrade
**Goal**: `yunohost app upgrade librechat` rebuilds LibreChat from updated source, preserves all user configuration and data, and leaves a working app.
**Depends on**: Phase 1 (rebuild uses same source/build pattern), Phase 2 (upgrade must not break backup/restore integrity)
**Requirements**: UPGR-01, UPGR-02, UPGR-03, UPGR-04, UPGR-05
**Success Criteria** (what must be TRUE):
  1. `yunohost app upgrade librechat` rebuilds the app from the new source tag and restarts services without manual intervention
  2. User-customized `librechat.env` (secrets) and `librechat.yaml` (provider config) are preserved verbatim after upgrade — new config keys are merged in, existing values are never overwritten
  3. MongoDB data (chat history, user accounts, agent config) and Meilisearch search indexes survive the upgrade intact
  4. The upgrade completes without npm `.cache` bloat remaining in the app tree
**Plans**: TBD

Plans:
- *(to be refined during planning)*

## Progress

**Execution Order:** Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Install | 0/TBD | Not started | - |
| 2. Remove + Backup/Restore | 0/TBD | Not started | - |
| 3. Upgrade | 0/TBD | Not started | - |
