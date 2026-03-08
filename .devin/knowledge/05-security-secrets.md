# Knowledge: Yu-Map Security and Secrets

**Trigger:** ALWAYS ACTIVE. Use for every task, especially those involving auth, data, external integrations, logging, uploads, admin actions, and persistence.

---

## Priority

If another instruction conflicts with this file, follow this file and escalate.

## Never Commit

- `.env` files
- API keys (Supabase, Google Maps, RevenueCat, Firebase, AdMob, Sentry, OpenAI, Bing)
- Tokens and passwords
- Client secrets and private keys
- Service account files
- Raw credentialed connection strings

## Sensitive Data

Treat as sensitive unless clearly proven otherwise:
- User credentials and tokens
- Session identifiers
- Personal data (email, username, display_name, avatar, bio)
- Payment/subscription data (RevenueCat entitlements)
- Review content and visit history
- Internal admin data

Never expose sensitive data in:
- Logs or error messages returned to users
- Screenshots
- Test fixtures with real values
- PR summaries

## Yu-Map-Specific Security

### AppConfig
- `app_config.dart` uses `String.fromEnvironment()` for compile-time injection of `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_KEY`.
- Default values in the file are placeholders. Never replace them with real keys.

### Supabase RLS
- RLS is enabled on `users`, `facilities`, `reviews`, `photos`.
- Public SELECT is allowed on most tables.
- Writes are restricted to the owning user via `auth.uid()`.
- Preserve or strengthen RLS policies. Never weaken them without approval.

### Edge Functions
- Use `SUPABASE_SERVICE_ROLE_KEY` (server-side only).
- Never expose service role keys in client code.

### RevenueCat
- API keys in `subscription_service.dart` are placeholders (`revenuecat_android_key`, `revenuecat_ios_key`).
- Never commit real RevenueCat keys.

### AdMob
- Test ad unit IDs are used in `ad_service.dart`. These are safe to commit.
- Never commit production ad unit IDs.

## Required Security Behavior

- Validate untrusted input at boundaries.
- Preserve or improve authorization checks.
- Use least-privilege assumptions.
- Keep logs safe and minimal.
- Use existing auth and permission patterns.

## Database Safety

- Do not run production-impacting data operations without approval.
- Do not assume destructive migrations are safe.
- All schema changes require approval.

## External Integrations

Before adding or changing an integration:
- Confirm approval.
- Confirm credential handling.
- Confirm sandbox vs production context.
- Confirm failure behavior.

## Security Incident Rule

If a vulnerability, secret leak, auth bypass, privilege escalation, or unsafe data exposure is discovered:
1. Stop immediately.
2. Do not continue silently.
3. Summarize the issue in plain language.
4. Wait for direction.
