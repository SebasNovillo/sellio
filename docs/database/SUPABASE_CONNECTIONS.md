# Supabase PostgreSQL connection preparation

Status: configuration prepared only. No Supabase connection, migration application or database modification is authorized by this setup task. The existing 22-model schema and initial migration are unchanged.

## Connection routing

| Variable | Copy from Supabase Dashboard > Connect | Consumer |
| --- | --- | --- |
| DATABASE_URL | Transaction pooler, shared Supavisor endpoint, port 6543 | NestJS PrismaService through PrismaPg |
| DIRECT_URL | Session pooler, shared Supavisor endpoint, port 5432 | Prisma CLI datasource.url in prisma.config.ts |

Copy the complete connection strings for the development project. Retain the dashboard's actual pooler host, database name and username (normally `postgres.<project-ref>` for the shared pooler). Do not derive the hostname from the region. Use the database password for the selected database role, not an anon/service-role API key. Percent-encode special characters in the username/password components; do not encode the entire URL or double-encode an already encoded password.

Here DIRECT_URL names a CLI connection variable; it intentionally contains the shared **session pooler** string, not the dashboard's raw direct IPv6 endpoint. Session pooling preserves the connection semantics needed by migration tooling. There is no fallback from DIRECT_URL to DATABASE_URL, and DATABASE_MIGRATION_URL is no longer read. A missing/blank DIRECT_URL permits offline validate/generate/build operations; connected CLI commands require it.

Prisma 7 places the CLI URL in prisma.config.ts, not in schema.prisma. Its former datasource.directUrl setting has been removed. The runtime adapter receives DATABASE_URL independently; it does not consult the CLI config or DIRECT_URL. See the [Prisma 7 config reference](https://www.prisma.io/docs/orm/v7/reference/prisma-config-reference).

## Runtime adapter and TLS

The pinned @prisma/adapter-pg 7.10.1 uses node-postgres. With statementNameGenerator unset, its query name is undefined and it does not cache named prepared statements. This is compatible with the shared transaction pooler's restriction on prepared statements. An offline adapter test verifies this behavior. Do not add a statement-name generator without re-evaluating compatibility. No adapter replacement or dependency upgrade is needed.

Supabase's generic Prisma examples include pgbouncer=true. This is not the mechanism disabling named statements in this Prisma 7 driver-adapter setup: the adapter's query options control that behavior. Do not rely on legacy URL parameters such as connection_limit to configure node-postgres pooling. The existing Nest singleton uses node-postgres's default pool maximum of 10 per API process; review the total across replicas against project limits before scaling. Transactions remain supported, but session state, session advisory locks, LISTEN/NOTIFY and temporary state must not be relied on across transactions. See [Supabase connection modes and limitations](https://supabase.com/docs/guides/database/connecting-to-postgres).

Require TLS on both real URLs: preserve existing query parameters and add sslmode=require (`?` for the first parameter, `&` thereafter), unless a certificate-verifying configuration is already supplied. This requires encryption but does not provide full server-identity verification in this setup. For verified TLS, configure the appropriate CA and sslmode=verify-full/sslrootcert for the selected endpoint before testing. Do not add rejectUnauthorized=false or disable TLS as a workaround. Certificate/network verification remains pending the approved live test; no certificate or connection has been fetched here.

## Local secret configuration

1. If apps/api/.env.local does not exist, copy apps/api/.env.example there. If it exists, edit only the relevant entries locally; do not overwrite it. No real environment file is created by this task.
2. Fill DATABASE_URL and DIRECT_URL only in that ignored backend file. Keep URLs out of frontend environment files, tracked examples, terminal command arguments, logs and screenshots. Quote the values in dotenv syntax. Do not send credentials in chat.
3. Both Nest and Prisma CLI load shell variables before apps/api/.env.local before apps/api/.env. Clear stale shell values privately if they mask the local file. Do not print their contents. Existing .env files remain supported, but keep one authoritative local definition per variable.
4. SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY and Stripe keys are not required for PostgreSQL connectivity and may stay empty. No Supabase SDK or auth/storage integration is introduced.

The existing .gitignore excludes .env and .env.* at all directory levels, except .env.example. Never force-add a real environment file. Backend credentials must not be copied into NEXT_PUBLIC_ variables. For deployed environments use server-side secret injection; Prisma CLI and API processes should receive only the secrets and privileges they need. Endpoint separation is not privilege separation: using the same database role in both URLs grants the same database privileges. Least-privilege role provisioning is a separate authorized database operation.

## Offline verification

From the repository root, using the pinned pnpm:

```sh
pnpm --filter @sellio/api db:validate
pnpm --filter @sellio/api db:generate
pnpm --filter @sellio/api test:database
pnpm lint
pnpm typecheck
pnpm build
git check-ignore apps/api/.env apps/api/.env.local
```

These checks do not test passwords, TLS handshakes, reachability, permissions or live schema state. Infrastructure tests use synthetic loopback URLs, intercept TCP and test CLI routing with explicit synthetic environment overrides. The existing health endpoint is process-only and is not a database connection test. The placeholder prisma.offline.config.ts remains restricted to local schema-only diff generation; never use it for a live connection or deployment.

## Next connection test: explicit approval required

1. Configure both real URLs privately as above and approve a **read-only connection test only**, identifying the intended development project without providing credentials in chat.
2. Test each endpoint sequentially with a bounded connection timeout and a single connection. Use DATABASE_URL through the runtime adapter and DIRECT_URL through a separate client. Inside a read-only transaction with a short statement timeout, run SELECT 1, current_database(), current_user and a server-version query; confirm TLS on the actual connection. Close both clients even on failure. Do not log the URLs or raw driver errors containing connection details.
3. Read catalog metadata only to check for conflicting initial-migration table/enum names and existing migration history. Do not modify Supabase-managed schemas. Report the sanitized identity, connectivity, TLS and privilege findings; do not run migrations during this test.
4. Request a separate approval for applying the reviewed initial migration. After that approval only, use the normal prisma.config.ts with DIRECT_URL for migrate deploy. Do not use migrate dev, db push or reset against this shared development project; shadow-database workflows require a separately isolated database and authorization.

Applying the migration is not yet a production-readiness decision. Review runtime role privileges and Supabase Data API exposure/RLS before enabling access to application tables; no role, grant, policy or existing database object is changed here.
