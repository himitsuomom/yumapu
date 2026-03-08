# Knowledge: Yu-Map Project Overview

**Trigger:** Use when starting a new task, deciding where to place code, or understanding product context.

---

## Product

Yu-Map (湯マップ) is a Flutter mobile app for discovering, reviewing, and tracking Japanese hot springs (onsen), public baths (sento), and saunas.

**Stage:** Early. Core models, services, database schema, and edge functions exist. UI screens are not yet implemented.

## Target Users

- People who visit or are curious about onsen/sento/sauna facilities in Japan.
- Users who want to discover, filter, review, and track facility visits.

## Core User Flows

1. Browse/search facilities on an interactive Google Map with clustering.
2. Filter by prefecture, type, amenities (tattoo-friendly, sauna, etc.), and search string.
3. Read and write reviews with ratings, photos, and likes.
4. Track visits and accumulate explorer/social points for a gamified ranking system.
5. Contribute and verify facility amenity data.
6. Access premium features via in-app subscription.

## Sensitive Areas

Treat these as high-risk and approval-gated:
1. Database schema changes (tables, RLS policies, functions, migrations)
2. Auth or permission changes (RLS policies, `users` table)
3. RevenueCat subscription or entitlement behavior
4. New external integrations or API keys
5. Edge function behavior changes (ranking calculation, contribution verification)
6. Breaking API changes
7. Production-impacting operations
8. User data handling (reviews, visits, photos, personal info)

## Monorepo Layout

| Path | Purpose |
|---|---|
| `yu_map/` | Flutter mobile application (all Flutter commands run here) |
| `yu_map/lib/` | App source code |
| `yu_map/lib/domain/entities/` | Domain value objects |
| `yu_map/lib/services/` | Service layer |
| `yu_map/test/` | Dart tests |
| `yu_map/supabase/migrations/` | PostgreSQL schema migrations |
| `yu_map/supabase/functions/` | Supabase Edge Functions (Deno/TS) |
| `research_summary.py` | Python CLI for AI research summarization (repo root) |
| `workflow.json` | n8n workflow for web research (repo root) |

## Placement Guidance

- New entities go in `yu_map/lib/domain/entities/`.
- New services go in `yu_map/lib/services/`.
- New tests go in `yu_map/test/`, mirroring the `lib/` structure.
- New migrations go in `yu_map/supabase/migrations/` with timestamp prefix.
- New edge functions go in `yu_map/supabase/functions/<name>/index.ts`.
- Follow the nearest existing file for naming and structure.

## Non-Goals

- Do not redesign the architecture unless explicitly requested.
- Do not reinterpret the product domain.
- Do not add UI screens unless explicitly requested (early stage).
