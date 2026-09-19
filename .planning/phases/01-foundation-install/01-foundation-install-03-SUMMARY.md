---
phase: 01-foundation-install
plan: 03
subsystem: ynh-packaging
tags: [gap-closure, manifest, systemd, multi-instance]
requires: []
provides:
  - "Pinned main-source sha256 (install no longer blocked)"
  - "Systemd units that survive ProtectSystem=full"
affects: [upgrade/backup design (Phase 3), multi-instance scope decision]
key-files:
  created: []
  modified:
    - manifest.toml
    - conf/meilisearch.service
    - conf/librechat.service
    - scripts/install
decisions:
  - "Multi-instance: set multi_instance=false for v1 (single-instance Meilisearch wiring retained; per-app wiring deferred)"
metrics:
  duration: ~6m
  completed: 2026-09-19
---

# Phase 01 Plan 03: Gap Closure (sha256, sandbox writes, multi_instance) Summary

**One-liner:** Closed all 3 install-blocking gaps — pinned the real v0.8.8-rc3 tarball sha256, granted ReadWritePaths under ProtectSystem=full in both units, and set multi_instance=false to match the single-instance Meilisearch wiring.

## What Was Done

1. **Gap #1 — sha256 blocker:** Downloaded `LibreChat archive refs/tags/v0.8.8-rc3.tar.gz` to the approved temp dir, computed `691cfe63aa4301d1c28821405a84b9725679fa0f4dbde0054d24bd80591c67d4`, pinned it in `[resources.sources.main]`. All three manifest sha256 entries are real hex hashes. No FILL_ME placeholder remains in any package file (remaining mentions are only in `.planning/` docs describing the fixed gap).
2. **Gap #2 — sandbox write denials:** Added `ReadWritePaths=__DATA_DIR__/meilisearch` to conf/meilisearch.service and `ReadWritePaths=__INSTALL_DIR__/logs __DATA_DIR__` to conf/librechat.service; pre-create + chown `$install_dir/logs` in scripts/install step 6 before service start. All hardening directives unchanged — writes granted, protection not relaxed.
3. **Gap #3 — multi_instance:** Checkpoint decision honored via auto-advance: **option-b — multi_instance = false** (planner-recommended). One manifest line, with comment noting per-app Meili wiring can be revisited later.
4. **Repo cruft:** Removed stray `librechat yunohost package.json` from repo root.

## Deviations from Plan

- Task 2's ordering note (run task 3 first on conf/meilisearch.service) became moot: option-b requires no ExecStart change, so task 3 didn't touch that file.
- gsd-tools `requirements mark-complete` found all five requirement IDs already marked Complete in REQUIREMENTS.md (previously marked) — no changes needed.

## Verification

- `bash -n scripts/install` passes (WSL bash)
- No FILL_ME in package files; main sha256 matches 64-hex pattern
- Both units contain ReadWritePaths; install creates logs dir before step 9
- `multi_instance = false` present in manifest [integration]

## Deferred Items

- Live-server items remain queued as `human_verification` in 01-VERIFICATION.md (full install run, streaming, nginx include, sandbox on real boot) — explicitly out of scope for this Windows machine.

## Self-Check: PASSED

- manifest.toml, conf/meilisearch.service, conf/librechat.service, scripts/install all exist and modified as claimed
- Commit d1dde68 exists (`fix(01-03): close install-blocking gaps ...`)
