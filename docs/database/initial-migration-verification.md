# Initial migration application and verification

**Date:** 2026-11-23 (America/Chicago)

**Status:** Applied and verified in the isolated sellio-dev environment. No further database changes are authorized by this record.

## Authorization and target

The owner explicitly authorized the existing `20261120000000_initial` migration and Prisma's required migration-history bookkeeping, conditional on a clean working tree, unchanged SQL, verified development target and safe Data API access. No other migration, schema change, seed data, business service, grant, RLS policy or infrastructure change was authorized or performed.

The target was the previously verified Supabase development project, PostgreSQL 17.12, UTF8, database `postgres`, schema `public`, role `postgres`. Runtime uses the shared transaction pooler; CLI uses only DIRECT_URL through the shared session pooler. Credentials and the official CA reference remain in ignored local configuration. This record contains no connection strings or machine-specific certificate paths.

## Preflight and Data API assessment

- The working tree was clean. Exactly one migration directory existed, and Prisma reported only the initial migration pending. Public relations and enums were empty; no migration-history relation existed in any schema.
- The reviewed SQL's SHA-256 was unchanged: `00e9084376d3d894acd2575dcc5999db2286b206b5eafd297a49cae35a5515b6`. No Prisma schema or migration SQL was regenerated or edited.
- Certificate and hostname validation succeeded with the independently downloaded official CA. Client-to-pooler and current-backend pooler-to-PostgreSQL connections both reported TLS 1.3 with `TLS_AES_256_GCM_SHA384`.
- Effective global/schema default privileges, role inheritance, schema usage and role login rights were inspected for the actual creator role. `anon`, `authenticated`, `service_role` and `authenticator` had no effective SELECT/INSERT/UPDATE/DELETE grants on tables that `postgres` would create in public. API roles had no inherited access to the creator role. The three API data roles cannot log in directly.
- `anon`, `authenticated` and `service_role` retain default TRUNCATE, REFERENCES, TRIGGER and MAINTAIN privileges. These are real SQL privileges, not a fully revoked access policy. Supabase documents that its Data API does not use those remaining privileges. Future SQL execution/RPC exposure requires a separate review.
- The Dashboard's Data API enablement and exposed-schema list were not independently observable from the stored PostgreSQL settings inspected. Security did not depend on assuming that the Data API was disabled: effective CRUD grants were denied even if public was exposed. There were no public RPC functions. Enabled provider DDL triggers were reviewed and did not grant access to application tables.
- The migration contains no RLS-enablement or permission statements. No automatic RLS-enablement trigger was found. Permission/RLS settings were not silently changed to pass preflight.

The access gate passed because the new tables would not receive Data API CRUD access. Residual non-CRUD grants and future access controls remain explicit security work. See [Supabase grants, defaults and Data API security](https://supabase.com/docs/guides/api/securing-your-api).

## Execution and migration history

The repository's pinned pnpm workspace and Prisma **7.10.1** ran only the deployment workflow:

```sh
pnpm --filter @sellio/api exec prisma migrate deploy --config prisma.config.ts
```

The CLI exited successfully and applied exactly `20261120000000_initial`. No reset, db push, migrate dev, manual replacement SQL or recovery action was used. Deployment used bounded connection/socket timeouts and the saved strict CLI CA settings.

Prisma recorded one completed migration with the exact SHA-256 checksum above, `applied_steps_count = 1`, a non-null finished timestamp and no rollback timestamp. The database recorded completion at `2026-11-24 04:59:31.787927+00` (2026-11-23 in America/Chicago). No incomplete or failed migration records were found. Post-deployment `prisma migrate status` exited 0, reported the schema up to date and listed no pending migrations.

## Verified live inventory and definitions

| Object | Application inventory |
| --- | ---: |
| Tables | 22 |
| Enum types | 13 |
| Columns | 205 |
| Primary keys | 22 |
| Foreign keys | 35 |
| Explicit unique indexes | 29 |
| Non-unique indexes | 30 |
| Partial unique indexes, included in the 29 | 7 |
| CHECK constraints | 14 |
| Automatic primary-key indexes, excluded from the 29 | 22 |

Prisma bookkeeping is separate: one `_prisma_migrations` table, one primary key on `id` and one automatic primary-key index. Public therefore contains 23 tables and 82 indexes in total: 59 explicit application indexes, 22 automatic application primary-key indexes and one history primary-key index.

Catalog definitions were compared with the complete reviewed SQL, not only counted:

- All 205 columns: ordered names, native types and sizes/precision, nullability and defaults. PostgreSQL's equivalent VARCHAR/character varying spellings were normalized.
- All 13 enums: exact names and ordered values. Catalog name arrays were cast to text arrays for driver decoding.
- All 22 primary keys: names and ordered columns.
- All 35 foreign keys: source/target schema, table and ordered columns, ON DELETE/ON UPDATE actions, match mode, validation and non-deferrability.
- All 59 explicit indexes: names, tables, ordered keys, uniqueness, predicates, btree method, validity/readiness, immediate uniqueness, included-column absence and sort options. PostgreSQL's equivalent IN/ANY and inserted type casts were normalized for predicate comparison.
- All 14 validated CHECK expressions: inventory balances; positive quantities; cart revision and exclusive ownership; checkout revision/retry/fingerprint/idempotency input; variant signatures; category self-parent protection; sale/reservation references; USD and finite/nonnegative monetary amounts; gross line totals; and the order-total equation.

Unique/FK definitions cover guest token hashes, one active customer cart, one live checkout per cart, durable customer/idempotency keys, source-cart conversion uniqueness, accepted-payment same-order ownership, reservation links and one SALE movement per reservation. **No definition discrepancies remained.** These checks establish deployed definitions; they do not replace future mutating, negative-case or concurrency integration tests.

## Connectivity, emptiness and access after deployment

Runtime Prisma queried representative User, Product, InventoryItem, CheckoutAttempt, Order and Payment models successfully. The actual Prisma CLI completed read-only queries against representative tables and a current-backend upstream-TLS assertion. Both endpoint modes retained verified client TLS 1.3 and reported upstream TLS 1.3 within the same read-only transactions as their backend identities.

Every one of the 22 application tables had exactly **zero rows**. No business/seed data was inserted. No application or history table granted effective CRUD access to anon, authenticated, service_role or authenticator. RLS remains disabled on the 22 application tables, as specified by the unchanged migration; the current access boundary is the denied API grants, not RLS.

Read-only verification used a maximum of one connection per endpoint, 10-second connection timeouts, 5-second server statement timeouts and bounded transaction/process deadlines. All local database clients and CLI processes closed. Provider-managed pooled backend sessions are outside the application's connection lifecycle.

Client certificate/hostname verification is confirmed. The observed upstream TLS does not independently establish Supabase's internal upstream certificate-validation policy or encryption on every provider-internal transport segment.

## Local checks

Prisma schema validation and Client generation passed. All eight existing offline database infrastructure tests passed. Workspace lint, TypeScript checks and builds passed using valid Turbo cache entries for unchanged source. Git diff whitespace checks passed. An existing nested-pnpm warning about useNodeVersion remains non-blocking; package-manager configuration was not changed. No dependency change, Git branch, commit or push is part of this task. Temporary diagnostic files were removed after verification.

## Outstanding security and development work

1. Approve and provision a dedicated least-privilege runtime role, with migration/DDL privileges kept separate. The current postgres role can bypass RLS; endpoint separation alone is not privilege separation.
2. Decide and verify the intended Data API/GraphQL exposure in the Dashboard. Keep business-data access behind NestJS unless another access path is explicitly designed. Do not add broad grants to resolve future permission errors.
3. Review residual default and existing non-CRUD grants, globally executable future functions and any RPC/SECURITY DEFINER exposure. Any permission changes require separate approval.
4. Establish appropriate grants and RLS policies before granting browser/API-facing access. Current lack of API CRUD grants must not be mistaken for deployed row policies or application authorization.
5. Implement and test immutable financial/address snapshots, audit/privacy retention, restricted historical updates/deletion and backend authorization. Existing FK actions preserve specified references, but do not implement all historical-record protections.
6. Review backups/restoration, secret management and CA renewal, runtime pool limits, deployment approvals, monitoring and production isolation before production deployment. Do not reuse development credentials or assumptions as production approval.
7. After separate approval, add database integration tests against an isolated disposable database for constraint failures, transaction behavior and concurrency. Seed data and business services remain out of scope.

Recommended next task: review and authorize runtime-role separation and Data API/grant/RLS hardening, followed by isolated database integration tests. No follow-on security changes, test fixtures, seeds or business features are implemented by this record.
