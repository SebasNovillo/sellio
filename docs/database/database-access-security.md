# Database access security implementation record

Date: 2026-11-25. **Part B.1: prepared only; not applied or live-tested.**

The owner approved the Part A access design for preparation. This document records repository artifacts, not permission to execute SQL, provision a test database, change credentials or perform a runtime cutover. The applied initial migration and Prisma schema remain unchanged. The last live audit is historical evidence; B.1 makes no Supabase connections.

## Approved design

- `sellio_runtime`: non-owner, NOLOGIN initially, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS. No memberships and no API-facing role may assume it. Password provisioning/login activation are separate B.2 steps.
- Existing postgres remains the controlled V1 migration/maintenance identity. Database, schema, table and enum ownership are preserved. No owner-group or managed-role changes are prepared.
- NestJS is the exclusive business-data layer. PostgreSQL roles are service identities, not CUSTOMER/MANAGER/ADMIN application roles.
- Explicit SELECT/INSERT on 22 application tables; column-level UPDATE on **17**; DELETE on **five**; no runtime TRUNCATE, REFERENCES, TRIGGER, MAINTAIN, persistent DDL or migration-history access.
- Command-specific RLS on all 22 tables: **22 SELECT + 22 INSERT + 17 UPDATE + 5 DELETE = 66 policies**. All policies target only sellio_runtime. User INSERT checks CUSTOMER. No runtime policy targets migration history.
- Remove all residual table/column access from PUBLIC and API-facing roles on exactly the 23 named targets. Future postgres-created public tables/sequences default to no runtime/API grants. No automatic runtime grants on future tables.

## Prepared artifacts

Files are under [apps/api/prisma/security](../../apps/api/prisma/security/README.md), outside Prisma's migrations directory:

| File | Role |
| --- | --- |
| access-manifest.json | Canonical reviewed application table/column matrix |
| 00-capture-state.sql | Read-only environment-specific ACL/owner/membership/policy snapshots |
| 01-create-runtime-role.sql | Guarded NOLOGIN creation; no password or activation |
| 02-apply-runtime-access.sql | Guarded, transactional grants, revokes, defaults and 66 policies |
| 03-verify-runtime-access.sql | Read-only catalog postconditions, not row-behavior tests |

Existing-object revocations explicitly name the 22 tables and `_prisma_migrations`; no schema-wide existing-object revocation assumes unrelated future public objects belong to Sellio. Default privileges are necessarily broader: PostgreSQL scopes them by creator/schema, not table-name pattern. Their future effect on postgres-created public objects requires review before B.2. Supabase-managed owner defaults are untouched. Unexpected global defaults, owners, memberships, migration baseline or existing policies abort mutation scripts. They must not be made to succeed through CASCADE, policy replacement or privilege escalation.

## Complete runtime matrix

SELECT/INSERT are allowed on every application row below. UPDATE is limited to the manifest's exact columns. All application IDs and created/received timestamps are excluded from UPDATE. The migration owner retains controlled ownership capabilities; API-facing roles receive none of these table privileges. Runtime owns no application object and receives no persistent DDL/TRUNCATE rights.

| Table | UPDATE scope | DELETE | Policies |
| --- | --- | --- | ---: |
| user | email, first_name, last_name, updated_at; never role/auth_id | No | 3 |
| address | saved address fields, default flag, updated_at | Yes | 4 |
| brand | name, slug, updated_at | No | 3 |
| category | name, slug, parent_id, status, updated_at | No | 3 |
| product | name, slug, description, status, brand_id, updated_at | No | 3 |
| product_category | None | Yes | 3 |
| product_image | storage_path, alt_text, position, is_primary, updated_at | Yes | 4 |
| product_option | name, position, updated_at | No | 3 |
| product_option_value | value, position, updated_at | No | 3 |
| product_variant | sku, price, compare_at_price, status, is_default, option_signature, updated_at | No | 3 |
| variant_option_value | None | Yes | 3 |
| inventory_item | quantity_on_hand, quantity_reserved, updated_at | No | 3 |
| inventory_reservation | status, updated_at; no quantity/expiry rewrite | No | 3 |
| inventory_movement | None | No | 2 |
| cart | user_id, guest_token_hash, status, revision, updated_at | No | 3 |
| cart_item | quantity, updated_at | Yes | 4 |
| checkout_attempt | status, order_id, processing/retry/retention/error metadata, updated_at | No | 3 |
| order | status, accepted_payment_id, reconciliation fields, paid_at, updated_at | No | 3 |
| order_item | None | No | 2 |
| order_address | None | No | 2 |
| payment | provider reference IDs, status, reconciliation fields, updated_at | No | 3 |
| payment_event | payment_id, processing_status, processed_at, error_code | No | 3 |
| _prisma_migrations | No runtime SELECT/INSERT/UPDATE | No | 0 |

Saved-address deletion, catalog-link/image deletion and cart-item deletion still need NestJS authorization and lifecycle guards. Product/category archival and variant deactivation remain the normal catalog lifecycle. Brand archival storage, staff provisioning and retention cleanup are deferred. No deletion permission is added to work around those gaps.

Database permissions prevent direct runtime rewrites of snapshots, movement rows, stable checkout inputs and receipt identity. They do not establish correct initial inputs, customer ownership, cross-row totals, accepted-payment once-only rules, lease fencing, provider truth, reserved-balance sums or transaction atomicity. Those remain service invariants under the original architecture. Privileged migration/maintenance identities are outside this runtime immutability boundary.

## RLS semantics

Policies are backend-wide for the allowed command, with true predicates except User INSERT requiring CUSTOMER. UPDATE policies exist only on the 17 mutable tables; DELETE policies only on the five deletion targets. Column ACLs further restrict UPDATE. RLS does not grant object privileges.

These policies do not implement customer-level authorization. NestJS must validate Supabase tokens, map verified subject to User.auth_id, load application permissions and enforce ownership/staff access. Prisma does not automatically receive a customer's JWT or auth.uid() context through the database URL. No policy is granted to PUBLIC, anon, authenticated, service_role or authenticator. BYPASSRLS roles remain privileged; do not grant them commerce access. FORCE RLS is not used to pretend that postgres's BYPASSRLS is constrained.

## Credential-loading architecture and staging

Repository configuration changes comprise `.gitignore`, `.dockerignore`, `apps/api/.env.example`, the new `.env.migrations.example`, `package.json`, `tsconfig.prisma.json`, `src/app.module.ts`, the new `src/config/environment-files.ts` and `runtime-environment.ts`, and `prisma.migrations.config.ts`. New offline coverage is in `test/environment.test.ts` and `test/security.test.ts`. No dependency or lockfile change is needed. Documentation updates cover the root/database READMEs, system architecture, Prisma foundation, Supabase connections, ADR-011, this record and the runbook; the security directory has its own artifact index.

The API now parses only allowlisted runtime keys through `src/config/runtime-environment.ts`. Nest's automatic dotenv merge and ConfigService process.env fallback are disabled. File values do not populate process.env. Shell > .env.local > .env precedence remains, paths are API-root-relative, and the selected DATABASE_URL/TLS query string is unchanged. Future integrations must use ConfigService and explicitly register new keys rather than assuming global dotenv mutation.

For B.1 compatibility, legacy mixed .env.local files are not edited: DIRECT_URL and legacy migration keys found there are ignored by runtime configuration. Inherited non-empty DIRECT_URL/DATABASE_MIGRATION_URL causes a sanitized startup refusal. This cannot erase a secret already supplied by the launcher; the runtime deployment must exclude it at source. The current DATABASE_URL identity is not switched to sellio_runtime in B.1.

`prisma.migrations.config.ts` is the prepared isolated CLI configuration: DIRECT_URL from shell > .env.migrations.local > .env.migrations only; no .env/.env.local read and no DATABASE_URL fallback. The example is `.env.migrations.example`. It does not activate until B.2 provisions the separate ignored CLI file and switches the operational entry point.

**The existing prisma.config.ts is intentionally unchanged as the current compatibility path.** It still loads the legacy files for connected CLI operations until the approved cutover. Do not claim current deployment credential separation from the prepared entry point alone. In B.2, replace the legacy loader/default entry point with the isolated configuration and remove the mixed migration entry under approval. No hidden fallback is introduced.

Build, typecheck, validation, generation and existing offline tests now use prisma.offline.config.ts, which reads no local secret files. Its loopback descriptor is schema-engine metadata, never a database-test endpoint. No live command is added to package scripts or CI.

Runtime environment examples contain no migration secret. `.gitignore` excludes real environment files and snapshots while allowing the new example. `.dockerignore` excludes environment files/snapshots from future Docker build contexts; no Docker deployment exists or is provisioned by B.1. The future runtime artifact must allowlist dist/production dependencies and exclude migration configs, tools and secret mounts. Verify this with the actual deployment provider.

Separate files under the same OS identity are a local convenience, not a security boundary against filesystem access by a compromised process. Production migration secrets must be absent from the runtime filesystem, environment and hosting identity's readable secret store. The official CA remains an external read-only runtime trust file; migration and pg URL CA parameter names remain distinct.

## Deferred risks

- PUBLIC TEMPORARY is unchanged; no persistent application DDL is granted, but temporary tables remain possible through inherited database rights.
- Global PUBLIC EXECUTE defaults are unchanged. Existing callable functions, especially SECURITY DEFINER functions, may provide indirect access outside table ACL/RLS checks and require an execution/search-path audit before exposing data. Every future application function must explicitly revoke unnecessary PUBLIC/API execution within its creation transaction; a schema-local default revoke cannot cancel the global default. No function privileges are changed in B.1.
- postgres remains a privileged owner/migrator. Ownership transfers and a new migration-owner role are deferred.
- Dashboard Data API settings remain owner-verified work. Disabling the Data API is approved in principle, not executed here. Auth/Storage dependency checks and their own API/bucket policies remain separate.
- Staff-role assignment, privacy/retention cleanup, corrections and production access remain separately approved workflows. No generalized SECURITY DEFINER escape hatch is added.

## Validation status

Offline checks passed: Prisma validation, Prisma Client generation (7.10.1), all 20 infrastructure/environment/security tests, workspace lint, TypeScript checks and builds. Unchanged workspace tasks used Turbo's local cache. Documentation links resolve; Git ignore checks protect real environment/snapshot files and allow both examples. Diff checks found no introduced whitespace errors; credential-pattern checks found no secrets in changed files. Hash comparisons confirm private environment files, schema.prisma and the applied initial SQL are unchanged. No dependencies were added.

The workspace commands emit an existing nested-pnpm warning about useNodeVersion; all checks exit successfully. No package-manager/runtime upgrade is made in this security task. Structural tests are not a PostgreSQL parser, grant/policy execution, live pooler authentication or proof of row behavior. No test database is provisioned in B.1. Isolated SQL/Prisma integration tests and the separately approved live preflight remain execution gates.

Use the [operational runbook](database-access-runbook.md) for the B.2 gates, isolated tests, manual Dashboard checklist and fail-closed recovery. Preserve [the applied migration record](initial-migration-verification.md) as historical evidence; no new Prisma migration or applied-history edit is created by preparation.
