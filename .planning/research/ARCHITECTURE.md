# Architecture Patterns

**Domain:** YunoHost native app package wrapping LibreChat (Node.js + MongoDB + Meilisearch)
**Researched:** 2026-09-18

## Recommended Architecture

```
┌──────────────────────────────────────────────────────┐
│                     YunoHost Host                     │
│                                                       │
│  ┌──────────────────────────────────────────────────┐ │
│  │              nginx (YNH-managed)                  │ │
│  │  ┌───────────────────────────────────────────┐   │ │
│  │  │  librechat.conf (YNH template)            │   │ │
│  │  │  proxy_pass http://127.0.0.1:$port/       │   │ │
│  │  │  WebSocket + SSE upgrade headers           │   │ │
│  │  │  proxy_buffering off                       │   │ │
│  │  └───────────────────────────────────────────┘   │ │
│  └──────────────────────────────────────────────────┘ │
│                         │                              │
│  ┌──────────────────────┴───────────────────────────┐ │
│  │          systemd: librechat.service                │ │
│  │  User: $app    Type: simple                        │ │
│  │  EnvironmentFile: $install_dir/librechat.env       │ │
│  │  ExecStart: $nodejs_dir/node api/server/index.js   │ │
│  │  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │ LibreChat API │  │ LibreChat UI │               │ │
│  │  │ (Node/Express)│  │  (React SPA)  │              │ │
│  │  └──────┬───────┘  └──────────────┘               │ │
│  │         │                                          │ │
│  │  ┌──────┴───────┐  ┌──────────────────────┐       │ │
│  │  │   MongoDB    │  │   Meilisearch        │       │ │
│  │  │   (MongoDB   │  │   (native binary)    │       │ │
│  │  │    upstream  │  │   systemd service)    │       │ │
│  │  │    repo)     │  │   port 7700          │       │ │
│  │  └──────────────┘  └──────────────────────┘       │ │
│  └──────────────────────────────────────────────────┘ │
│                                                       │
│  Data:                                                │
│  ├── /var/www/librechat/          (install_dir)       │
│  ├── /home/yunohost.app/librechat/ (data_dir)         │
│  └── /var/log/librechat/          (log directory)     │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| nginx (YNH) | TLS termination, reverse proxy, WebSocket upgrade, SSE buffering off | LibreChat API (127.0.0.1:$port), Internet |
| LibreChat API (Node) | Express server, LLM proxy, conversation management, auth | MongoDB (127.0.0.1:27017), Meilisearch (127.0.0.1:7700), LLM providers (external) |
| LibreChat UI (React SPA) | Frontend served by API server | LibreChat API (same origin) |
| MongoDB | Conversation storage, user data, agent config | LibreChat API |
| Meilisearch | Message/conversation search index | LibreChat API |

### Data Flow

1. **User request:** Browser → HTTPS → nginx ($domain) → proxy_pass (http://127.0.0.1:$port)
2. **Chat request:** User message → LibreChat API → upstream LLM provider (OpenAI, Anthropic, etc.)
3. **Streaming response:** LLM provider → SSE stream → LibreChat API → nginx (buffering off) → Browser
4. **Search:** User search query → LibreChat API → Meilisearch → results → user
5. **Persistence:** Chat messages → MongoDB (via Mongoose/ORM)
6. **WebSocket:** Real-time updates (multi-device, stream resume) → WebSocket through nginx upgrade

## Patterns to Follow

### Pattern 1: YunoHost Package Structure (v2)
**What:** Standard directory layout with `manifest.toml`, `scripts/`, `conf/`, `doc/`, `patches/`
**When:** Always. Required by YNH core.
**Reference:**
```
librechat_ynh/
├── manifest.toml
├── scripts/
│   ├── _common.sh
│   ├── install
│   ├── upgrade
│   ├── remove
│   ├── backup
│   ├── restore
│   └── change_url
├── conf/
│   ├── nginx.conf
│   ├── librechat.service
│   ├── meilisearch.service
│   ├── librechat.env
│   └── librechat.yaml
├── doc/
│   ├── DESCRIPTION.md
│   ├── ADMIN.md
│   └── screenshots/
└── tests.toml
```

### Pattern 2: MongoDB Namespaced Setup (Wekan Pattern)
**What:** Use `ynh_install_mongo` to install MongoDB globally, then `ynh_mongo_setup_db` to create an app-specific database and user.
**When:** All MongoDB-using YNH apps.
**Example:**
```bash
# In _common.sh
mongo_version="7.0"

# In install
ynh_install_mongo
db_name=$(ynh_sanitize_dbid --db_name=$app)
db_user=$db_name
ynh_app_setting_set --key=db_name --value=$db_name
ynh_mongo_setup_db --db_user=$db_user --db_name=$db_name

# In remove (NEVER call ynh_remove_mongo)
ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name
```

### Pattern 3: Config Merge on Upgrade (Never Overwrite)
**What:** Preserve user-modified config files during upgrade. Append new keys without removing user customizations.
**When:** Any YNH package where users modify config files.
**Example:**
```bash
# In install script:
ynh_config_add --template="librechat.env" --destination="$install_dir/librechat.env"

# In upgrade script (keeps user file):
ynh_setup_source --dest_dir="$install_dir" --keep="librechat.env librechat.yaml" --full_replace=1
# Then: merge new keys into existing files without overwriting
```

### Pattern 4: Hardened systemd Unit (Wekan Pattern)
**What:** Sandbox the Node.js process with systemd security options.
**When:** All Node.js services.
**Example:**
```systemd
[Service]
User=__APP__
Group=__APP__
EnvironmentFile=__INSTALL_DIR__/librechat.env
WorkingDirectory=__INSTALL_DIR__/
ExecStart=__NODEJS_DIR__/node api/server/index.js
Restart=on-failure

NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=full
ProtectHostname=yes
ProtectClock=yes
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Docker-in-a-Package
**What:** Wrapping Docker Compose in a YNH package via systemd running `docker compose up -d`.
**Why bad:** Project requirement is native install. Docker adds 500MB+ overhead, loses YNH integration (backup/restore, nginx), hits Docker Hub rate limits in CI, and is philosophically opposed by YNH core team.
**Instead:** Native install from source tarball + systemd service.

### Anti-Pattern 2: Calling `ynh_remove_mongo` in Remove Script
**What:** Removing the global MongoDB installation when removing the app.
**Why bad:** Multiple YNH apps may share the same MongoDB instance (Wekan, MyDrive). `ynh_remove_mongo` destroys the service for all apps.
**Instead:** Use `ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name` to remove only the app's database and user.

### Anti-Pattern 3: Raw Data Directory Backup for MongoDB
**What:** Running `ynh_backup "$data_dir"` to capture MongoDB data files.
**Why bad:** MongoDB data files are not consistent when copied live. Restore will produce a corrupted database.
**Instead:** Use `ynh_mongo_dump_db --database=$app > ./dump.bson` for a logical, consistent backup.

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| MongoDB storage | Shared `ynh_install_mongo` instance | Dedicated MongoDB server | MongoDB replica set |
| Meilisearch | Co-located binary | Dedicated Meilisearch | Meilisearch cluster |
| LibreChat API | Single Node process | Multiple processes with Redis | Horizontal scaling with Redis + load balancer |
| nginx | Single YNH proxy | YNH proxy (fine) | External load balancer |
| npm build time | ~5-10 min on modern hardware | N/A (one-time build) | N/A |
| Disk usage (npm build) | ~500MB with .cache | ~500MB | ~500MB (cache cleaned) |

## Sources

- [YunoHost App Structure Documentation](https://yunohost.org/en/dev/packaging/structure) — HIGH confidence
- [YunoHost App Scripts Documentation](https://yunohost.org/en/dev/packaging/scripts/) — HIGH confidence
- [Wekan Install Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/install) — HIGH confidence (verified MongoDB + systemd pattern)
- [Wekan systemd Service](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/conf/systemd.service) — HIGH confidence (hardened sandboxing pattern)
- [Wekan Remove Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/remove) — HIGH confidence (namespaced cleanup pattern)
- [Wekan Backup Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/backup) — HIGH confidence (mongodump backup pattern)
- [Wekan Restore Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/restore) — HIGH confidence (MongoDB restore pattern)

---
*Architecture research for: LibreChat YunoHost Package*
*Researched: 2026-09-18*
