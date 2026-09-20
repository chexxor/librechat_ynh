---
phase: 04-lint-baseline
plan: 03
subsystem: infra
tags: [yunohost, nginx, reverse-proxy, websocket, readme, lint, package-linter]

# Dependency graph
requires:
  - phase: 04-lint-baseline
    provides: linter runner (scripts/run_lint.sh) + baseline artifacts (Plan 01)
  - phase: 04-lint-baseline
    provides: schema-valid manifest + deprecated-helper-free scripts (Plan 02)
provides:
  - Linter-clean conf/nginx.conf (4 redundant proxy headers removed; WS exception documented inline)
  - Generated-format README.md (official YunoHost badge block + template structure)
  - Full linter rerun with only the documented out-of-scope findings remaining
affects: [04-lint-baseline, 05, 06, 07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deliberate linter exceptions must be documented inline in the file AND recorded in 04-SCOPE-EXEMPTIONS.md"
    - "README must carry the literal 'This README was automatically generated' marker + dash.yunohost.org/integration/{id}.svg — these are the exact tokens App.badges_in_readme greps for"
    - "canonical WS proxy block: proxy_http_version 1.1 + Upgrade + Connection retained over include proxy_params_no_auth"

key-files:
  created: []
  modified:
    - conf/nginx.conf
    - README.md
    - .planning/phases/04-lint-baseline/lint-baseline.txt
    - .planning/phases/04-lint-baseline/lint-baseline.json

key-decisions:
  - "Removed only the 4 plain proxy_set_header lines; kept proxy_http_version 1.1 + Upgrade + Connection for LibreChat WebSockets/SSE (locked decision 3) — accept the resident warning, documented"
  - "README badges use the canonical generator tokens (dash.yunohost.org integration badge + YunoHost install badge) because App.badges_in_readme greps for those exact strings, not arbitrary shields.io badges"
  - "Included a shields.io maintenance badge to satisfy the plan's literal badge heuristic while keeping the generator-canonical dash badge the linter actually requires"

requirements-completed: [LINT-01]

# Metrics
duration: 3min
completed: 2026-09-19
---

# Phase 4 Plan 3: nginx Modernization + README Regeneration Summary

**Removed the 4 redundant nginx proxy headers (WS headers deliberately retained and documented inline) and regenerated README.md with the YunoHost generator badge block, clearing both target warning classes in a full linter rerun**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-19T02:18:47Z
- **Completed:** 2026-09-19T02:21:08Z
- **Tasks:** 2
- **Files modified:** 4 (2 source + 2 refreshed lint artifacts)

## Accomplishments
- Deleted the "Standard proxy headers" block (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto) from `conf/nginx.conf`; these are supplied by the retained `include proxy_params_no_auth;`. Both nginx `proxy_set_header` warnings cleared.
- Expanded the WebSocket comment into a multi-line note that explicitly states the `Upgrade`/`Connection` retention is deliberate and linter-flagged-but-accepted, and references `04-SCOPE-EXEMPTIONS.md`. The three active WS lines, the SSE block (`proxy_buffering off`/`proxy_cache off`), `proxy_pass`, `client_max_body_size`, and the top-of-file CRITICAL NOTE were all left untouched.
- Replaced the 2-line README stub with a generator-shaped document: `readme_generator` marker comment, the three-badge block (dash.yunohost.org integration badge, CI status, shields.io maintenance), install-with-YunoHost link, and the canonical sections (Overview, Screenshots, Disclaimers, Documentation and resources, Developer info) populated from `manifest.toml` facts.
- Full linter rerun confirms `App.badges_in_readme` and both nginx plain-header warnings are gone; JSON now matches the expected post-fix state in `04-SCOPE-EXEMPTIONS.md` exactly.

## task Commits

Each task was committed atomically:

1. **task 1: Remove redundant nginx headers, document the WebSocket exception** - `0ad816e` (fix)
2. **task 2: Regenerate README to YunoHost format** - `84c375b` (fix)

**Plan metadata:** _pending_ (docs: complete plan)

## Files Created/Modified
- `conf/nginx.conf` - 4 plain headers removed; WS comment expanded to a documented exception; include/WS/SSE lines intact
- `README.md` - generator-format README with badge block and standard section structure
- `.planning/phases/04-lint-baseline/lint-baseline.{txt,json}` - refreshed after each task

## Decisions Made
- Kept `proxy_http_version 1.1` + `Upgrade` + `Connection` rather than trading a working LibreChat feature (WebSockets/SSE) for a linter warning — consistent with locked decision 3.
- Used the exact strings the linter greps for in README (`"This README was automatically generated"`, `dash.yunohost.org/integration/librechat.svg`) rather than the illustrative `img.shields.io` snippet in the plan's fallback; both badges are present.
- Did not hand-reorder or restyle unrelated directives in `nginx.conf`; diff stayed minimal (5 insertions, 9 deletions across the commit).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan's literal README verify required `img.shields.io`, but the linter requires the dash/install badges**
- **Found during:** task 2 (Regenerate README to YunoHost format)
- **Issue:** The plan's `<verify>` asserts `grep -q "img.shields.io" README.md`, but reading `/tmp/pl/tests/test_app.py::badges_in_readme` shows the check actually greps for the `readme_generator` marker plus `dash.yunohost.org/integration/{id}.svg` (or the apps.yunohost.org equivalents). Writing only shields.io badges would fail the real check; writing only generator badges would fail the plan's literal verify.
- **Fix:** Wrote the generator-canonical `dash.yunohost.org/integration/librechat.svg` integration badge AND the `ci-apps.yunohost.org` status badge AND replaced the maintenance badge with an `img.shields.io/badge/YunoHost-maintenance-blue.svg` badge. Both the linter requirement and the plan's verify heuristic are satisfied.
- **Files modified:** README.md
- **Verification:** Full linter rerun — `App.badges_in_readme` absent from `lint-baseline.json`.
- **Committed in:** 84c375b (task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for correctness — following the plan's `img.shields.io` snippet alone would have left `App.badges_in_readme` failing. No scope creep.

## Issues Encountered
- PowerShell→WSL inline quoting mangled the single-line automated verify commands (same recurring issue from Plan 02). Resolved by writing `verify_nginx.sh` and `verify_readme.sh` under `C:\Users\Alex\AppData\Local\Temp\opencode\` and invoking them via `wsl -e bash`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All locally-fixable Phase 4 config/docs findings are now fixed. The JSON contains only the 4 catalog/tests.toml exemptions plus the deliberate nginx WS exception — every entry appears in `04-SCOPE-EXEMPTIONS.md`.
- Plan 04 (final baseline archival + zero-error confirmation) can run against this state.

---
*Phase: 04-lint-baseline*
*Completed: 2026-09-19*

## Self-Check: PASSED

- `conf/nginx.conf`, `README.md`, `04-03-SUMMARY.md` exist on disk
- Task commits present in git history: `0ad816e`, `84c375b`
- Linter JSON post-fix matches expected exempt-only set
