# Arr Client — Claude Code Instructions

## Context files

Local context files (`.claude/context/`) provide detailed reference on demand:

| File | Contents |
|------|----------|
| `architecture.md` | Code examples: CachedDataLoader, service singletons, three-state pattern, release dialog, API endpoints, auth headers, encryption specs |
| `branching-strategy.md` | Branch model, naming rules, PR targets, full issue→branch→PR lifecycle |
| `workflows.md` | Daily dev commands, pre-commit checklist, feature development steps, test commands |

---

## Documentation policy

- **README.md** — user-facing: setup, features, troubleshooting
- **RELEASE.md** — release process and CI/CD workflow guide
- **CLAUDE.md** — this file: architecture overview and development patterns
- Do not create additional doc files. Answer questions in chat; update README only for core user-facing changes.

---

## Architecture overview

Three core singletons form the foundation:

**`AppStateManager`** (`lib/services/app_state_manager.dart`)
Single source of truth for active instances. `ChangeNotifier` that broadcasts instance changes and coordinates cache invalidation. Owns all instance CRUD (`addSonarrInstance`, `deleteSonarrInstance`, `updateSonarrInstance`, etc.) — never call `InstanceManager` CRUD directly from screens or services, always go through `AppStateManager`.

**`CacheManager`** (`lib/services/cache_manager.dart`)
In-memory cache with instance-aware keys (e.g. `series_list_instance123`). 5-minute validity with stale-while-revalidate. Cache keys must be globally unique across all screens.

**`CachedDataLoader`** (`lib/utils/cached_data_loader.dart`)
Mixin for all data-loading screens. Provides the standard loading → loaded/error/empty pattern, cache checking, and background refresh. See `architecture.md` for full usage example.

**Service layer** (`SonarrService`, `RadarrService`)
Singleton API clients that listen to `AppStateManager` and auto-reset their `ApiClient` when the active instance changes. Lazy initialisation on first use.

**Typed models** — API responses use `freezed` + `json_serializable` models under `lib/models/`. History, queue, release search, and manual import screens convert typed results to `Map<String, dynamic>` via `.toJson()` at the boundary to preserve complex existing card-builder code. `ServiceInstance` remains the only model outside `lib/models/`.

---

## Code conventions

**Naming**
- Classes: `PascalCase` — screens: `FeatureNameScreen`, services: `ServiceNameService`, state: `_FeatureNameScreenState`
- Files: `snake_case.dart`
- Private members: `_prefixed`

**File organisation**
- One main widget per file; related helpers in the same file
- No barrel exports — direct imports everywhere
- Absolute imports from `lib/`

**State management**
- `setState()` only — no Provider, Bloc, Riverpod, or any library
- All data screens use `CachedDataLoader` mixin
- Services are singletons; screens never instantiate them with `new`

**Data access**
- Always null-check: `data['field'] ?? 'default'`
- Always check lists: `(data['list'] as List?)?.length ?? 0`
- Always check `mounted` before `setState()` after async operations

**Error handling**
- Always use `ErrorFormatter.format(e)` for user-facing messages
- Every error state must have a retry button

**Navigation**
- `MaterialPageRoute` with direct constructors — no named routes

---

## Security rules

- **Never commit** API keys, passwords, tokens, real instance URLs, or backup passwords
- Credentials → `flutter_secure_storage` only
- Metadata (names, URLs) → `SharedPreferences`
- `ErrorFormatter` sanitizes credentials from error messages automatically

---

## Common pitfalls

1. Use `CachedDataLoader` for top-level list screens only — dialogs, search screens, and detail screens use the three-state pattern directly (see `architecture.md`). Don't force `CachedDataLoader` onto screens that don't have pull-to-refresh
2. Never call `InstanceManager` CRUD directly — all instance add/update/delete goes through `AppStateManager`
3. Cache keys must be globally unique (instance suffix is the same per service, two screens with the same base key collide)
4. `RefreshIndicator` requires a scrollable child (ListView, CustomScrollView, etc.)
5. Empty state ≠ error state — different icons, messages, and CTAs
6. Service reset is automatic — `AppStateManager` calls `reset()` on any notification (including credential edits on the active instance — do not add an ID guard)
7. All crypto must run in isolates via `compute()` — never on the UI thread
8. `saveFile()` on mobile requires the `bytes` parameter; desktop uses the returned path
9. `TextEditingController` must be declared as a field, initialized in `initState`, and disposed in `dispose()` — never created inline in `build()` (memory leak, cursor position lost on every rebuild)
10. For `PUT` endpoints that accept a list body, use `ApiClient.putList()` — `put()` expects a `Map`, not a `List`
11. Sonarr/Radarr `PUT /series` and `PUT /movie` require the ID in the URL — use `PUT /series/{id}` and `PUT /movie/{id}`. Omitting the ID returns 405.
12. Manual import is **not** `PUT` or `POST /manualimport` — that endpoint only reprocesses candidates. Actual import is `POST /command` with `name: ManualImport`, `files: [...]`, `importMode: move`.
13. `GET /queue` defaults to page size 10. Always pass `pageSize` — current services use 500. Without it the queue silently truncates.
14. `ApiClient` catch blocks must have `on ApiException { rethrow; }` before the generic `catch (e)` — otherwise HTTP errors thrown by `_handleResponse` get double-wrapped as "Network error: ...".
15. Episode monitoring uses `PUT /episode/monitor` with `{ episodeIds: [...], monitored: bool }` — do not fetch the full episode object and PUT it back just to toggle a boolean.

---

## Critical files

| File | Role |
|------|------|
| `lib/main.dart` | App entry, Material3 theme, AppStateManager init |
| `lib/services/app_state_manager.dart` | Single source of truth, ChangeNotifier |
| `lib/services/cache_manager.dart` | Singleton cache, instance-aware keys |
| `lib/services/instance_manager.dart` | Persistent storage (secure + SharedPreferences) |
| `lib/services/api_client.dart` | HTTP client, `/api/v3` prefix, auth headers, error handling |
| `lib/services/sonarr_service.dart` | All Sonarr API methods, lazy client init |
| `lib/services/radarr_service.dart` | All Radarr API methods, lazy client init |
| `lib/services/backup_service.dart` | AES-256-GCM backup/restore with isolate crypto |
| `lib/services/biometric_service.dart` | Biometric auth, 5-minute re-auth timeout (hardcoded) |
| `lib/config/app_config.dart` | Synchronous getters delegating to AppStateManager |
| `lib/utils/cached_data_loader.dart` | Mixin for consistent loading patterns |
| `lib/utils/error_formatter.dart` | User-friendly errors, credential sanitization |
| `lib/models/service_instance.dart` | Only typed data model in the app |
| `lib/screens/home_screen.dart` | Bottom nav, AppStateManager listener, IndexedStack |
| `lib/screens/settings_screen.dart` | Instance management |
| `lib/screens/series_list_screen.dart` | Reference implementation of CachedDataLoader |
| `lib/screens/release_search_screen.dart` | Unified release dialog for series and movies |
| `lib/screens/queue_screen.dart` | Combined Sonarr+Radarr queue, remove, manual import entry point |
| `lib/screens/manual_import_screen.dart` | Manual import flow — candidate list, edit dialog, import execution |
| `test/widget_test.dart` | All tests (21 passing) |
