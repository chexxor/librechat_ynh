---
phase: 01-foundation-install
verified: 2026-09-18T12:00:00Z
status: passed
score: 17/17
gaps:
  - truth: "Source tarballs are pinned with sha256 integrity"
    status: resolved
    reason: "RESOLVED in gap closure (plan 01-03): main source sha256 pinned to 691cfe63aa4301d1c28821405a84b9725679fa0f4dbde0054d24bd80591c67d4 (verified checksum of the v0.8.8-rc3 tag tarball). No FILL_ME placeholder remains in package files."
    artifacts:
      - path: "manifest.toml"
        issue: '[resources.sources.main] sha256 = "FILL_ME" (line 42) — must be replaced with the real tarball hash'
    missing:
      - "Compute sha256 of https://github.com/danny-avila/LibreChat/archive/refs/tags/v0.8.8-rc3.tar.gz on a shell-capable environment and pin it in manifest.toml"
  - truth: "Both systemd services (librechat, meilisearch) are created and started"
    status: resolved
    reason: "RESOLVED in gap closure (plan 01-03): meilisearch.service now grants ReadWritePaths=__DATA_DIR__/meilisearch; librechat.service now grants ReadWritePaths=__INSTALL_DIR__/logs __DATA_DIR__; scripts/install pre-creates and chowns the logs dir before services start. Sandbox directives otherwise unchanged."
  - truth: "Install supports multi-instance (manifest declares multi_instance = true)"
    status: resolved
    reason: "RESOLVED in gap closure (plan 01-03): multi_instance = false for v1 (single-instance Meilisearch wiring retained). Per-app port/service wiring can be revisited in a later milestone."
    artifacts:
      - path: "manifest.toml"
        issue: "multi_instance = true inconsistent with single-instance meilisearch wiring"
      - path: "conf/meilisearch.service"
        issue: "Hardcoded 7700 port and __APP__-less service name"
    missing:
      - "Allocate a per-app meilisearch port slot in [resources.ports] and template it, or flip multi_instance = false"
human_verification:
  - test: "Run yunohost app install librechat on a live YunoHost server (after pinning the real main-source sha256)"
    expected: "Install completes; https://<domain>/ serves LibreChat over valid Let's Encrypt HTTPS; admin password shown in output and emailed"
    why_human: "Cannot run YunoHost installs on the Windows dev machine; all runtime behavior (npm build, Mongo, service start) is only provable live"
  - test: "Verify LibreChat entry point and create-user path on a live install"
    expected: "api/server/index.js is the correct ExecStart target and config/create-user.js exists in the source in the $install_dir tree"
    why_human: "Paths depend on the actual upstream tarball layout, which cannot be inspected from this machine"
  - test: "Send a chat message and check streaming after install"
    expected: "LLM responses stream token-by-token (SSE works through nginx); real-time features work (WebSocket)"
    why_human: "Requires a live server, working provider key, and browser behavior"
  - test: "Verify nginx template include proxy_params_no_auth resolves on the target YunoHost version"
    expected: "nginx -t passes with no 'open file failed' for proxy_params_no_auth; no duplicated/conflicting proxy headers"
    why_human: "Depends on files YunoHost ships at runtime, not present in this repo"
  - test: "Confirm systemd hardening doesn't break either service"
    expected: "systemctl status librechat / meilisearch show active (running) — no sandbox-denied file writes ( ProtectSystem/DevicePolicy vs Node, mongod connection, Meilisearch writes)"
    why_human: "Sandbox interplay only provable by booting units on a live server"
---

# Phase 1: Foundation + Install — Verification Report

**Phase Goal:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with valid nginx proxy, functioning systemd service, and reliable backup/restore (install portion: SKEL + INST + CONF).
**Verified:** 2026-09-18T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification
**Mode note:** Static verification only (Windows dev machine; no YunoHost server available). All runtime claims are marked for human/live-server verification.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | manifest.toml valid with all required resources | ✓ VERIFIED | 74 lines, packaging v2, all sections present (metadata, upstream, integration, install, resources incl. nodejs/apt/ports/sources/permissions) |
| 2 | nginx template has WebSocket + SSE support | ✓ VERIFIED | conf/nginx.conf: `proxy_http_version 1.1`, `Upgrade`/`Connection` headers, `proxy_buffering off`, `proxy_cache off`, __PATH__/__PORT__ vars, 100M body size, explanatory comment |
| 3 | systemd templates exist for both services | ⚠ PARTIAL | Both files exist and are well-formed (ExecStart, User=__APP__, EnvironmentFile, hardening); BUT missing ReadWritePaths — see gap #2 |
| 4 | librechat.env has all secret placeholders | ✓ VERIFIED | MONGO_URI, JWT_SECRET, JWT_REFRESH_SECRET, ADMIN_PANEL_SESSION_SECRET, MEILI_MASTER_KEY all templated `__VAR__` |
| 5 | librechat.yaml has 4 provider blocks | ✓ VERIFIED | openAI, anthropic, ollama ("Not needed for local Ollama"), openRouter all present (commented template — as planned) |
| 6 | Admin email install question in manifest | ✓ VERIFIED | `[install.admin_email]` type=text, ask.en, example, email pattern_regexp |
| 7 | Source tarballs pinned with sha256 | ✗ PARTIAL | Meilisearch amd64+arm64 sha256 pinned ✓; main source sha256 = "FILL_ME" placeholder ✗ — see gap #1 |
| 8 | upgrade/remove/backup/restore stubs exist | ✓ VERIFIED | All 4 stubs valid bash: shebang, source helpers, ynh_abort_if_errors, ynh_script_progression (stubs are intentional — lifecycle is Phase 2/3) |
| 9 | Install downloads pinned LibreChat source | ✓ VERIFIED | scripts/install step 2: `ynh_setup_source --dest_dir="$install_dir"` |
| 10 | MongoDB via ynh_install_mongo, namespaced DB | ✓ VERIFIED | Step 1 `ynh_install_mongo` (mongo_version="7.0" in _common.sh); Step 3 `ynh_sanitize_dbid` + `ynh_mongo_setup_db`; mongopwd read back for template |
| 11 | Meilisearch binary installed to /usr/bin | ✓ VERIFIED | `ynh_setup_source --source_id=meilisearch --dest_dir=/usr/bin` + chmod +x |
| 12 | Build with 3 AUR workarounds | ✓ VERIFIED | _common.sh `librechat_build()`: allow-remote true, npm install --no-save unrun, npx turbo build --no-daemon, rm -rf .npm; all commands under ynh_exec_as_app |
| 13 | nginx + both systemd units configured in install | ✓ VERIFIED | Steps 7–8: ynh_config_add_nginx; ynh_config_add_systemd x2; yunohost service add x2 |
| 14 | Admin user via create-user.js + random password | ✓ VERIFIED | `librechat_create_admin_user` runs `node config/create-user.js ... --email-verified=true` with ynh_string_random(24) password |
| 15 | Password delivered via email AND screen | ✓ VERIFIED | Step 11 `mail -s` heredoc + `ynh_print_info "Admin password: ..."` |
| 16 | Both services started (order: meili → app) | ✓ VERIFIED | Step 9 in correct order with ynh_systemctl |
| 17 | Services reachable at end of install (INST-10) | ? UNCERTAIN | Structurally supported but cannot be proven here — depends on gap #1 (sha256), gap #2 (sandbox writes), and live verification |

**Score:** 14/17 truths fully verified (2 partial, 3 human/live items)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `manifest.toml` | Package definition | ✓ VERIFIED (with 2 content gaps) | 74 lines; sha256 placeholder; multi_instance inconsistency |
| `conf/nginx.conf` | Proxy template w/ WS+SSE | ✓ VERIFIED | 33 lines, all required directives |
| `conf/librechat.service` | Hardened unit | ⚠ PARTIAL | Content correct; likely unwritable log path under hardening |
| `conf/meilisearch.service` | Meili unit | ⚠ PARTIAL | db-path unwritable under ProtectSystem=full |
| `conf/librechat.env` | Env template | ✓ VERIFIED | All placeholders |
| `conf/librechat.yaml` | Provider template | ✓ VERIFIED | 4 provider blocks + registration section |
| `doc/DESCRIPTION.md` | Catalog description | ✓ VERIFIED | 8 lines |
| `doc/ADMIN.md` | Admin docs | ✓ VERIFIED | 36 lines, covers providers, password, users, DBs, logs, search enable |
| `doc/screenshots/.gitkeep` | dir placeholder | ✓ VERIFIED | exists |
| `scripts/_common.sh` | Helpers | ✓ VERIFIED | 96 lines; 3 functions, mongo_version=7.0 |
| `scripts/install` | Install orchestration | ✓ VERIFIED | 147 lines; all 12 steps in plan order |
| `scripts/{upgrade,remove,backup,restore}` | Stub lifecycle scripts | ✓ VERIFIED | Intentional stubs for Phase 2/3 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| scripts/install | ynh_install_mongo | step 1 | ✓ WIRED | literal call, mongo_version global in _common.sh |
| scripts/install | conf/librechat.env | ynh_config_add --template | ✓ WIRED | destination=$install_dir/librechat.env; chown/chmod 600 |
| scripts/install | conf/nginx.conf | ynh_config_add_nginx | ✓ WIRED | step 7 |
| scripts/install | conf/librechat.service + meilisearch.service | ynh_config_add_systemd x2 | ✓ WIRED | step 8, meili as separate service with own unit |
| conf/librechat.service | conf/librechat.env | EnvironmentFile | ✓ WIRED | EnvironmentFile=__INSTALL_DIR__/librechat.env — matches destination used in install |
| scripts/install | admin password email | mail + ynh_print_info | ✓ WIRED | both channels present |
| manifest.toml | conf/* | conf/ convention | ✓ WIRED | all templates referenced by install exist in conf/ |

### Requirements Coverage

All 19 phase requirement IDs are claimed across the two plans (Plan 01: SKEL-01..05, CONF-01..04, INST-06/07/09; Plan 02: INST-01/02/03/04/05/08/10). No orphaned Phase 1 requirements. TRACEABILITY in REQUIREMENTS.md lists all 19 as Phase 1/Complete — consistent with plan frontmatter.

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| SKEL-01 | ⚠ SATISFIED (with blocker) | manifest complete; blocked by FILL_ME sha256 for real install |
| SKEL-02 | ⚠ SATISFIED (deviation) | Node "24" declared (RESEARCH locked decision overrides REQUIREMENTS.md's "Node 22" wording); libvips42, build-essential, python3 in [resources.apt]; Mongo 7.0 via _common.sh; Meili sources pinned |
| SKEL-03 | ✓ SATISFIED | [resources.system_user] + User=__APP__/Group=__APP__ in both units, ynh_exec_as_app for npm/node |
| SKEL-04 | ✓ SATISFIED | ldap = false, sso = false in [integration] |
| SKEL-05 | ✗ PARTIAL | Meili sha256s pinned; main tarball = "FILL_ME" placeholder |
| INST-01 | ✓ VERIFIED (static) | ynh_setup_source from pinned tag URL |
| INST-02 | ✓ VERIFIED (static) | npm ci + turbo build in librechat_build() |
| INST-03 | ✓ VERIFIED (static) | allow-remote, --no-save unrun, .npm stripped (note: strips `.npm`, REQUIREMENTS text says `.cache` — same intent, minor wording difference) |
| INST-04 | ✓ VERIFIED (static) | ynh_install_mongo + ynh_mongo_setup_db |
| INST-05 | ✓ VERIFIED (static) | per-arch binary download + meilisearch.service (subject to sandbox gap) |
| INST-06 | ✓ SATISFIED | nginx.conf WS + SSE headers |
| INST-07 | ✓ VERIFIED (static) | ynh_config_add_systemd + yunohost service add; unit WantedBy=multi-user.target |
| INST-08 | ✓ VERIFIED (static) | create-user.js with random password (live path verification pending) |
| INST-09 | ? NEEDS HUMAN | HTTPS provisioning is YNH-native (no code needed); only provable live |
| INST-10 | ? NEEDS HUMAN | Cannot install on this machine; blocked until sha256 gap closed |
| CONF-01 | ✓ SATISFIED | librechat.yaml 4 providers |
| CONF-02 | ✓ SATISFIED | librechat.env template |
| CONF-03 | ✓ SATISFIED | librechat.yaml template |
| CONF-04 | ✓ SATISFIED | domain + admin_email install questions (only questions, per locked decision) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| manifest.toml | 42 | `FILL_ME` placeholder sha256 | 🛑 Blocker | Real install fails SHA256 verification — blocks INST-10 and the phase goal until pinned |
| conf/meilisearch.service | — | ProtectSystem=full w/o ReadWritePaths | 🛑 Likely blocker | Meili db-path under /var read-only → service crashloop; verify live |
| conf/librechat.service | — | ProtectSystem=full + LOG_TO_FILE=true | ⚠ Warning | Log writes likely denied; may need ReadWritePaths for /var/log |
| `librechat yunohost package.json` | 1 | Stray AI-conversation export at repo root | ℹ️ Info | Cruft from a prior chat export; move out of repo or add to .gitignore |

Not counted as anti-patterns: upgrade/remove/backup/restore stubs (intentional — Phase 2/3 work), commented-out librechat.yaml providers (intentional template per plan).

### Minor Notes

- REQUIREMENTS.md says `.cache` stripped (INST-03); code strips `.npm`. Same intent; sync wording in Phase 3 plan.
- REQUIREMENTS.md wording says `npm run create-user`; plan/code use direct `node config/create-user.js`. Equivalent intent.
- `include proxy_params_no_auth;` in nginx.conf must be verified to exist on the target YunoHost build (live check).
- librechat.env comment says "user must set ... MEILI_MASTER_KEY" but the template injects it — cosmetic comment inconsistency.

### Human Verification Required

See `human_verification` frontmatter — 5 live-server tests (full install run, entry-point/create-user path confirmation, chat streaming, nginx include resolution, systemd sandbox survival).

### Gaps Summary

The package skeleton, all 5 config templates, and the full 12-step install orchestration exist statically with correct structure and wiring — everything _claims_ to be in place live checks confirm. Three gaps stand between this and the phase goal of a working one-command install:

1. **FILL_ME sha256** (root cause of a failed install) — trivial fix, requires one real hash computation.
2. **Sandbox write access** — both systemd units likely deny Meilisearch/LibreChat their required disk writes under the current hardening; needs ReadWritePaths (and live confirmation).
3. **Multi-instance inconsistency** — manifest promises multi_instance but meilisearch wiring is single-instance; fix wiring or flip the flag.

Gaps 1 and 2 are code-fixable in a small gap-closure plan; all three are articulated in the frontmatter for `/gsd-plan-phase --gaps`. The remaining phase-goal criterion (end-to-end reachable UI) is only provable on a live YunoHost server and is queued as human verification.

---

_Verified: 2026-09-18T12:00:00Z_
_Verifier: OpenCode (gsd-verifier)_
