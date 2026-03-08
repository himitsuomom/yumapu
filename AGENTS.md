# AGENTS.md — Yu-Map (yumapu)

This file is the top-level entry point for AI agents working in this repository.

## Repository Structure

```
yumapu/                          # Repo root
├── yu_map/                      # Flutter mobile application
│   ├── lib/                     # App source code
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/config/         # AppConfig (compile-time env)
│   │   ├── domain/entities/     # Equatable value objects
│   │   └── services/            # Service layer (Supabase, Maps, Ads, etc.)
│   ├── test/                    # Dart unit/widget tests
│   ├── pubspec.yaml             # Flutter dependencies
│   └── supabase/
│       ├── migrations/          # PostgreSQL schema migrations
│       └── functions/           # Supabase Edge Functions (Deno/TS)
├── research_summary.py          # Python CLI for AI research summarization
├── workflow.json                # n8n workflow for web research
├── .devin/                      # Devin agent documentation
│   ├── knowledge/               # Yu-Map-specific knowledge files
│   └── playbooks/               # Repeatable task playbooks
└── docs/devin-sessions/         # Session retrospectives
```

## Product

Yu-Map (湯マップ) is a Flutter mobile app for discovering, reviewing, and tracking Japanese onsen, sento, and saunas. Early stage: core models, services, schema, and edge functions exist. UI screens are not yet implemented.

## Technical Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart SDK >= 3.2) |
| State management | Riverpod |
| Backend | Supabase (PostgreSQL + PostGIS, RLS, Edge Functions) |
| Edge functions | Deno / TypeScript |
| Maps | Google Maps Flutter |
| Payments | RevenueCat |
| Analytics | Firebase Analytics |
| Ads | Google AdMob |
| Error tracking | Sentry |
| Research tools | Python, n8n |

## Commands

All Flutter commands run from `yu_map/`:

| Action | Command | Working directory |
|---|---|---|
| Install dependencies | `flutter pub get` | `yu_map/` |
| Run tests | `flutter test` | `yu_map/` |
| Static analysis / lint | `flutter analyze` | `yu_map/` |
| Build | Not established repo-wide. Do not guess. | — |

## Default Branch

`main`

## Key Patterns

- **Entities**: `yu_map/lib/domain/entities/` — Equatable value objects with `fromJson(Map<String, dynamic>)` factories. JSON keys use snake_case.
- **Services**: `yu_map/lib/services/` — Constructor-injected `SupabaseClient`, private `_cache` fields, public unmodifiable getters.
- **Tests**: `yu_map/test/` mirrors `lib/`. Uses `group()` + `test()` with manual mock classes and `mocktail`.
- **Migrations**: `yu_map/supabase/migrations/` — Timestamped SQL files. All tables use UUID PKs, RLS enabled.
- **Edge Functions**: `yu_map/supabase/functions/<name>/index.ts` — Deno imports, `serve()` pattern.

## Approval-Gated Changes

These require explicit user approval before implementation:

1. Database schema changes (tables, RLS policies, functions, migrations)
2. Auth or permission changes
3. RevenueCat subscription or entitlement behavior
4. New external integrations or API keys
5. Edge function behavior changes (ranking, contribution verification)
6. Breaking API changes
7. Production-impacting operations

## Documentation

- Agent knowledge: `.devin/knowledge/`
- Task playbooks: `.devin/playbooks/`
- Session retrospectives: `docs/devin-sessions/`

These repo-managed docs are the source of truth for Yu-Map-specific behavior.
