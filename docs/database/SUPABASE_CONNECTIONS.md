# Supabase PostgreSQL connection preparation

Status: strict TLS on both observed connection hops was verified after the owner enabled SSL enforcement. Following separate authorization, the unchanged initial migration was applied and verified in sellio-dev on 2026-11-23; see the [deployment record](initial-migration-verification.md). Further database modifications require separate approval.

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

Use the CA downloaded independently from the authenticated development project's Database > Settings > SSL Configuration > Download Certificate. Keep it in a local file outside the repository, and reference its URL-encoded absolute path in the ignored backend environment file. No system-wide trust-store changes or startup flags are required. Preserve the existing host, port, username, password, database and unrelated URL parameters.

| Consumer | Required TLS query parameters |
| --- | --- |
| Runtime DATABASE_URL, PrismaPg/node-postgres | sslmode=verify-full&sslrootcert=<encoded absolute CA path> |
| Prisma CLI DIRECT_URL, installed Prisma 7.10.1 migration engine | sslmode=require&sslaccept=strict&sslcert=<encoded absolute CA path> |

The parameter names are deliberately different. node-postgres uses sslrootcert for the server CA and sslcert for a client certificate. The installed Prisma migration engine successfully verified the server using sslcert with sslaccept=strict; supplying only sslrootcert did not resolve its trust failure. Do not feed the CLI URL unchanged into node-postgres. For a separate pg-based session-endpoint diagnostic, translate its CA setting in memory to sslrootcert with sslmode=verify-full; verify the actual CLI separately using its original configured URL.

In the installed pg-connection-string 2.14.1, sslmode=require currently validates certificates by default; it is inaccurate to describe that mode universally as encrypt-only. Other drivers and libpq compatibility mode have different semantics. Runtime uses the explicit verify-full mode, and CLI uses its engine's require plus strict settings. Never enable validation bypasses or change hostname checks. When mixing a URL with an explicit adapter ssl object, URL SSL parameters can replace that object; the current application uses the URL alone. See [node-postgres SSL configuration](https://node-postgres.com/features/ssl), [Prisma SSL guidance](https://www.prisma.io/postgres/ssl-connection-error), and [Supabase verified TLS setup](https://supabase.com/docs/guides/platform/ssl-enforcement).

## Historical read-only verification before initial migration: 2026-11-23

The dashboard-provided Supabase Root 2021 CA is a CA certificate with a valid self-signature, no private key, and validity through 2031-04-26. Its SHA-256 fingerprint is `80:70:25:AD:50:D4:ED:21:9D:2C:9C:7D:29:9C:00:4F:82:4E:B0:0C:F7:F6:5A:FE:F6:07:D0:7B:72:E6:CA:FA`. Trust came from the independent dashboard download, not from accepting a certificate supplied by a failing endpoint.

- Both configured endpoints authenticated and reported PostgreSQL 17.12, UTF8, database postgres, schema public and role postgres. Their configured project references agree; the dashboard display name cannot be independently obtained from these PostgreSQL queries.
- Both client-to-pooler sockets negotiated TLS 1.3, reported authorized=true and validated the pooler hostname. The actual runtime Prisma Client and adapter completed the read-only metadata queries. The actual Prisma CLI completed a BEGIN READ ONLY / SELECT 1 / ROLLBACK script with the saved CLI settings.
- Negative tests removed the CA only from diagnostic child/in-memory configurations. Runtime rejected the chain with SELF_SIGNED_CERT_IN_CHAIN; Prisma CLI rejected it with P1011 and a Windows untrusted-root error. Saved URLs were not weakened.
- Public tables, views and enums were empty. No _prisma_migrations relation was found in any schema, and no relation/type/index names conflicted with the initial migration's 22 tables, 13 enums and 59 explicit indexes. No Supabase Auth/Storage records were read or modified.
- Connection timeouts were 10 seconds, metadata statement timeouts 5 seconds, and transaction/overall deadlines were bounded. Catalog name/char types were cast to text for Prisma raw-query compatibility. All database clients and diagnostic processes closed after verification.

These observations are a point-in-time check, not an application of the migration. No schema objects or records were created, altered or deleted. Temporary diagnostic files are removed after verification.

### Remaining operational review

The earlier, pre-enforcement check reported ssl=false for the pooler-to-PostgreSQL hop. The owner subsequently enabled Supabase SSL enforcement. Fresh pre/post-migration checks of both modes now report ssl=true, TLS 1.3 and TLS_AES_256_GCM_SHA384 for the current backend, within the same read-only transaction as identity inspection. Client sockets retain verified CA/hostname checks. The earlier upstream-encryption blocker is resolved; the internal upstream certificate-validation policy and every provider-internal transport layer remain independently unverified. No infrastructure setting was changed by migration execution. See [Supabase SSL enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement).

Both URLs currently authenticate as postgres, so endpoint separation is not least-privilege role separation. Review runtime privileges and Supabase Data API exposure/RLS before application access. No role, grant or policy was changed.

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
