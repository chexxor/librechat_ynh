# Phase 1: Foundation + Install - Context

**Gathered:** 2026-09-18
**Status:** Ready for planning

<domain>
## Phase Boundary

YunoHost package skeleton + install scripts that produce a working LibreChat web UI behind HTTPS with MongoDB, Meilisearch, nginx, and systemd. Install questions, build, and service orchestration are in scope. Provider API keys and post-install configuration belong in the config template files, not install prompts.

</domain>

<decisions>
## Implementation Decisions

### Install questions
- **Admin email** — Prompts user during install for admin email (standard YunoHost pattern). Not auto-derived from YNH admin.
- **Admin password** — Generated as a strong random password during install. Shown at end of install output AND emailed to the admin email address. User can change it later in LibreChat account settings.
- **LLM API keys** — NOT requested during install. User configures provider keys in `librechat.yaml` after install. Keeps install flow minimal and template-driven.
- **Domain / path** — Standard YunoHost domain prompt only. App installs at root path (`/`). No sub-path support for v1.

### OpenCode's Discretion
- Exact random password generation method (length, character set)
- Email template / wording for the password email
- Install question ID naming convention in manifest
- Whether to show the admin email confirmation prompt as optional or required
- Default domain selection logic (first domain or prompt always)

</decisions>

<specifics>
## Specific Ideas

- "Random + email it + shown once at end of install" — password delivery should be redundant: both screen output and email
- Standard YunoHost install question style — domain prompt is built into YNH, admin email should feel natural alongside it
- Clean separation: install sets up the app, config files set up the LLM

</specifics>

<deferred>
## Deferred Ideas

- Provider API key prompting during install — could be a future install question enhancement, but out of scope for v1
- Sub-path install support — out of scope for v1, reserved for multi-instance or shared-domain scenarios

</deferred>

---

*Phase: 01-foundation-install*
*Context gathered: 2026-09-18*
