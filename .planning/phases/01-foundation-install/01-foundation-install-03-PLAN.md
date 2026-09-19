---
phase: 01-foundation-install
plan: 03
type: execute
wave: 1
depends_on: []
files_modified: [manifest.toml, conf/meilisearch.service, conf/librechat.service, scripts/install]
autonomous: false
gap_closure: true
requirements: [SKEL-05, SKEL-01, INST-05, INST-07, INST-10]
user_setup: []

must_haves:
  truths:
    - "manifest.toml contains a real sha256 for the main LibreChat source (no FILL_ME placeholder) so ynh_setup_source passes on a live install"
    - "Both systemd units declare ReadWritePaths so their required disk writes succeed under ProtectSystem=full"
    - "Manifest multi_instance setting is consistent with the Meilisearch wiring (no port/service-name collision on a second install)"
  artifacts:
    - path: "manifest.toml"
      provides: "Pinned main-source sha256 + consistent multi_instance flag"
      contains: "sha256"
    - path: "conf/meilisearch.service"
      provides: "Unit with writable db-path"
      contains: "ReadWritePaths"
    - path: "conf/librechat.service"
      provides: "Unit with writable log path"
      contains: "ReadWritePaths"
  key_links:
    - from: "conf/meilisearch.service"
      to: "__DATA_DIR__/meilisearch (db-path)"
      via: "ReadWritePaths grants write access under ProtectSystem=full"
      pattern: "ReadWritePaths=.*meilisearch|ReadWritePaths=.*__DATA_DIR__"
    - from: "manifest.toml"
      to: "multi_instance wiring"
      via: "flag matches either per-app port/service template or is disabled"
      pattern: "multi_instance"
---

<objective>
Close the 3 gaps found by phase verification so `yunohost app install librechat` can complete end-to-end on a live server.

Purpose: Gap #1 (FILL_ME sha256) hard-blocks every real install. Gap #2 (systemd sandbox denies writes) likely crashloops both services. Gap #3 (multi_instance inconsistency) breaks a declared packaging contract.

Output: Fixed manifest.toml, fixed systemd unit templates, repo cruft removed.
</objective>

<execution_context>
@~\.config\opencode/get-shit-done/workflows/execute-plan.md
@~\.config\opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-foundation-install/01-foundation-install-01-SUMMARY.md
@.planning/phases/01-foundation-install/01-foundation-install-02-SUMMARY.md
@manifest.toml
@conf/meilisearch.service
@conf/librechat.service

**Source of gaps:** `.planning/phases/01-foundation-install/01-VERIFICATION.md` (status: gaps_found, score 14/17)
**Gap reason codes:** G1 = FILL_ME sha256 blocker; G2 = sandbox write denials; G3 = multi-instance inconsistency
</context>

<tasks>

<task type="auto">
  <name>task 1: Pin real main-source sha256 (closes gap #1)</name>
  <files>manifest.toml</files>
  <action>
    Download the exact pinned tarball and compute its sha256 (GitHub archive tarballs for a fixed tag are byte-stable):
    1. Download to the approved temp dir: `Invoke-WebRequest -Uri "https://github.com/danny-avila/LibreChat/archive/refs/tags/v0.8.8-rc3.tar.gz" -OutFile "$env:TEMP\opencode\librechat-v0.8.8-rc3.tar.gz"`
    2. Compute hash: `(Get-FileHash "$env:TEMP\opencode\librechat-v0.8.8-rc3.tar.gz" -Algorithm SHA256).Hash.ToLower()`
    3. Replace `sha256 = "FILL_ME"  # Compute at build time` (manifest.toml line 42, [resources.sources.main]) with the computed lowercase 64-char hex hash. Remove the "Compute at build time" comment.
    Do NOT guess or hardcode a hash anywhere else; only [resources.sources.main].
  </action>
  <verify>
    <automated>Select-String -Path manifest.toml -Pattern "FILL_ME" ; must return NO matches; then `Select-String -Path manifest.toml -Pattern 'sha256 = "[a-f0-9]{64}"'` must match in [resources.sources.main]</automated>
    <manual>manifest.toml has three sha256 entries total (main, amd64, arm64), all real hex hashes</manual>
    <sampling_rate>run after this task commits</sampling_rate>
  </verify>
  <done>[resources.sources.main].sha256 is a real 64-char hex hash and "FILL_ME" no longer appears anywhere in the repo</done>
</task>

<task type="auto">
  <name>task 2: Fix systemd sandbox write access (closes gap #2)</name>
  <files>conf/meilisearch.service, conf/librechat.service, scripts/install</files>
  <action>
    Gap reason: ProtectSystem=full mounts /var read-only, so Meilisearch's db-path (`__DATA_DIR__/meilisearch`) and LibreChat's file logging are denied.

    1. conf/meilisearch.service: in the hardening block, add:
       `ReadWritePaths=__DATA_DIR__/meilisearch`
       (one path — Meili only writes its index there).
    2. conf/librechat.service: add a ReadWritePaths line granting the log location. LibreChat with LOG_TO_FILE=true writes via its logger under the install dir; grant the whole install dir's writable subpaths explicitly:
       `ReadWritePaths=__INSTALL_DIR__/logs __DATA_DIR__`
       and, because ProtectSystem=full also blocks logs/ creation, pre-create the log dir in scripts/install before services start (currently step 9 starts services): add in the config step (step 6, after templates are written), as the __APP__-owning directory:
       ```bash
       mkdir -p "$install_dir/logs"
       chown "$app:$app" "$install_dir/logs"
       ```
       Place it immediately before or with the librechat.env chmod block in step 6.
    3. Keep ALL existing hardening directives unchanged — add lines only, do not relax the sandbox (the fix is granting writes, not removing protection).
    4. Update the meilisearch ExecStart only if task 3 (decision) resolves to per-app wiring — otherwise leave ExecStart untouched in this task; task 3 owns that file decision. (See task 3 conflict note: run task 3 first if merging; the tasks share conf/meilisearch.service, so in execution treat task 3's resolution as final for that file.)
  </action>
  <verify>
    <automated>Select-String -Path conf/meilisearch.service,conf/librechat.service -Pattern "ReadWritePaths=" ; both files must match; `bash -n scripts/install` must pass; Select-String -Path scripts/install -Pattern "mkdir -p .*logs" must match</automated>
    <manual>Both units retain their full hardening block with ReadWritePaths appended; log dir created before step 9 service start</manual>
    <sampling_rate>run after this task commits</sampling_rate>
  </verify>
  <done>Both unit templates contain ReadWritePaths covering the paths each service writes; install creates + chowns the logs dir before services start; bash -n passes</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>task 3: Resolve multi_instance inconsistency (closes gap #3)</name>
  <files>manifest.toml, conf/meilisearch.service, scripts/install, conf/librechat.service</files>
  <action>PAUSE for user selection. On assignment, execute the corresponding implementation block below. Run this task BEFORE task 2 reaches its final state on conf/meilisearch.service (option-a changes that file's ExecStart).</action>
  <verify>manifest [integration] flag matches the chosen option: option-b → `Select-String -Path manifest.toml -Pattern 'multi_instance = false'` matches; option-a → a second port slot exists in [resources.ports] and the unit contains `__APP__` in its templated name/path references</verify>
  <done>Manifest multi_instance setting is consistent with the Meilisearch wiring as chosen by the user</done>
  <decision>How to reconcile `multi_instance = true` with the single-instance Meilisearch wiring (hardcoded 7700, shared /usr/bin/meilisearch binary, shared service name "meilisearch")</decision>
  <context>
    A second install of this app today would collide on port 7700 and clobber both the /usr/bin binary and the systemd unit. Verification explicitly offers two resolutions. This decides packaging scope for v1 and affects Phase 2/3 (upgrade/backup) design.
  </context>
  <options>
    <option id="option-a">
      <name>Fix wiring for true multi-instance</name>
      <pros>Honors the declared contract; standard YNH practice (per-app port slot, per-app service name e.g. meilisearch-__APP__)</pros>
      <cons>More changes now: add a port slot (e.g. meili.default = 7700) to [resources.ports], template port + unit name, rename binary/install per-app; more live-server risk surface in Phase 1</cons>
    </option>
    <option id="option-b">
      <name>Set multi_instance = false for v1 (recommended)</name>
      <pros>Minimal change: one manifest line; removes collision risk immediately; can revisit per-app wiring later</pros>
      <cons>Users cannot run two LibreChat apps on one YunoHost server in v1</cons>
    </option>
  </options>
  <implementation-if-option-a>
    manifest.toml: add `[resources.ports.ports.meili]` style second port slot (YNH port resource syntax: another `X.default = 7700` key, e.g. `meili.default = 7700`), template ExecStart to `--http-addr 127.0.0.1:__PORT_MEILI__` per how the helper exposes the second port variable, rename the unit to `meilisearch-__APP__.service` via ynh_config_add_systemd's --name/template mechanism, and source the meilisearch binary to a per-app path (e.g. /opt/meilisearch-__APP__/meilisearch via a dedicated source dest_dir) instead of /usr/bin. Update scripts/install (steps 2, 8) and conf/librechat.service Wants/After lines to the new unit name, and librechat.env MONGO_URI-adjacent MEILI_HOST if it references port 7700.
  </implementation-if-option-a>
  <implementation-if-option-b>
    Change `multi_instance = true` to `multi_instance = false` in manifest.toml [integration]. No other changes.
  </implementation-if-option-b>
  <resume-signal>Select: option-a or option-b, or describe an alternative resolution</resume-signal>
</task>

<task type="auto">
  <name>task 4: Remove stray repo cruft (verification anti-pattern, info severity)</name>
  <files>"librechat yunohost package.json" (repo root)</files>
  <action>
    Verification flagged a stray file "librechat yunohost package.json" at the repo root (prior AI-chat export cruft). Inspect it; it is not part of the YNH package. Remove it with `Remove-Item` (confirm with the user only if it looks intentionally hand-curated). Update .gitignore only if needed to prevent recurrence (it is not).
  </action>
  <verify>
    <automated>Test-Path "librechat yunohost package.json" must be False</automated>
    <done>Repo root contains no stray chat-export file</done>
  </verify>
</task>

</tasks>

<verification>
<automated>HASH_OK=$(Select-String -Path manifest.toml -Pattern 'FILL_ME' -Quiet -NotMatch); [regex] matching main source sha256 is 64-hex; conf/meilisearch.service and conf/librechat.service both contain ReadWritePaths=; bash -n scripts/install passes; multi_instance decision reflected in manifest (either false, or per-app port + unit name present)</automated>
All three verification gaps from 01-VERIFICATION.md frontmatter have a corresponding closure in this plan.
</verification>

<success_criteria>
- No "FILL_ME" placeholder anywhere in the repository
- Both systemd units grant ReadWritePaths for their required writes, sandbox otherwise unchanged
- multi_instance flag consistent with Meilisearch wiring (per user decision)
- Log dir created and owned by __APP__ before service start in scripts/install
- bash -n passes on scripts/install
- Live-server items (full install run, streaming, nginx include, sandbox on real boot) remain queued as human_verification in 01-VERIFICATION.md — explicitly out of scope for this Windows machine
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation-install/01-foundation-install-03-SUMMARY.md`
</output>
