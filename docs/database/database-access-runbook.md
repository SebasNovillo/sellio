# Database access hardening operational runbook

Date: 2026-11-25. **B.1 preparation only. No database or Dashboard execution is authorized by this document.**

## B.2 approval gates

Obtain separate owner approval identifying sellio-dev, the exact reviewed SQL revision, the isolated test environment, maintenance window, secret-isolation method and runtime cutover. New approval is also required for the Dashboard change. Deferred TEMPORARY/global EXECUTE/ownership/staff/retention changes must not be added to this operation.

The files under [prisma/security](../../apps/api/prisma/security/README.md) are not Prisma migrations and have no automatic runner. Do not use migrate dev/reset, db push, generate a replacement initial migration or replay the applied initial migration to apply security changes. Capture an operational change record without falsifying Prisma migration history.

## Fresh target and snapshot preflight

1. Verify clean/reviewed repository state and the unchanged initial migration/schema. Confirm only the expected migration history exists and compare its checksum with the manifest. Detect live schema drift before applying grants.
2. Independently verify project identity from the approved private connection configuration/Dashboard. The SQL's postgres database/role names and history checksum are useful abort gates, not a unique dev-project identifier; production could have the same names and baseline.
3. Verify the official CA provenance, strict hostname/certificate settings, runtime transaction port and owner session port, and TLS on both observed hops within one read-only transaction. Do not print URLs, passwords or raw driver errors.
4. Inventory unrelated public objects, memberships, global defaults, ownership and policies. Review callable functions, especially SECURITY DEFINER execution grants and safe search_path settings, for indirect access that table ACLs/RLS cannot prevent. Do not change global EXECUTE defaults or managed functions in this operation. Stop on changes from the reviewed state; never widen the object allowlist automatically.
5. With an approved read-only client, capture all outputs of `00-capture-state.sql` into an owner-only environment-specific snapshot outside Git (for example the ignored API .security-snapshots directory). Include table/column ACL grantors/options, owners, defaults, policy expressions, role flags/memberships, schema/database ACLs and migration checksum. Do not capture role passwords, secret values, migration logs or business rows. Prisma db execute does not return SELECT result sets and is not a snapshot-capture tool.
6. Review and sign off the snapshot before any mutation. A missing/unreviewed snapshot is a blocker. Preserve preflight and post-apply snapshots separately; raw preflight permissions are evidence, not an automatically safe rollback target.

## Manual Dashboard dependency checklist

Record non-secret evidence for the intended project:

- Is Enable Data API on? Which consumers actually use generated REST/GraphQL/RPC endpoints?
- What schemas are exposed? Is public exposed? Do not infer this from a 401 response without an API key or from absent SQL settings.
- Is Automatically expose new tables/objects enabled? Inspect actual grants; toggling this is not a substitute for reviewing existing privileges.
- Are frontend/backend integrations using only Supabase Auth methods for sign-in/session management, or do they also query business data through .from()/RPC/GraphQL? Search current source and verify planned flows before changing the setting.
- Confirm planned Auth token issuance/JWKS validation remains separate from direct commerce-table access. Do not disable Auth or modify auth schema grants to disable the Data API.
- Confirm planned Storage calls use the Storage API with separately reviewed bucket/storage.objects policies or authorized server operations. They do not justify commerce-table CRUD grants. Do not modify storage schema grants/policies here.
- Verify admin/frontends use NestJS for business operations. If any existing consumer requires Data API business access, stop for an explicit architecture/dependency decision rather than restoring blanket grants.

After separate Dashboard approval and dependency verification, the target is Data API disabled. If a future feature needs a data endpoint, approve a restricted exposed surface separately; do not move the existing 22 tables or add a speculative API schema in this task. Validate Auth/Storage behavior when those integrations exist. No live feature dependency is certified by B.1.

## Isolated PostgreSQL test plan: provision only after approval

Use a disposable, independently identified PostgreSQL 17 instance/database with no shared production/dev storage or credentials. The guarded SQL expects a database named postgres; use an isolated instance with that database name rather than weakening target guards or pointing tests at sellio-dev.

The approved test bootstrap must create only local stand-in API roles needed by the scripts: anon, authenticated, service_role (including its intentional bypass flag), and authenticator. These stand-ins do not reproduce every managed Supabase behavior. Apply the unchanged initial migration through pinned Prisma deploy, capture state, then run the prepared role/access SQL. No fixtures are inserted into sellio-dev.

| Test area | Required evidence |
| --- | --- |
| Role | NOLOGIN before activation; no ownership/memberships; no superuser, create-role/database, replication or bypass flags |
| Scope | Add an unrelated public test object and prove its existing ACL/owner/policies remain unchanged |
| Positive operations | SELECT/INSERT on 22, allowed column updates on 17 and leaf/configuration deletion on five |
| Immutable columns | Deny all other updates, including IDs, User.role/auth_id, order totals/snapshots, stable checkout inputs, payment amounts and event receipt identity |
| Append-only history | Deny UPDATE/DELETE on inventory_movement, order_item and order_address |
| User insertion | CUSTOMER/default succeeds through actual Prisma; MANAGER/ADMIN insertion fails; role updates fail |
| RLS | 66 exact policies; API identities remain denied; accidental SELECT grant in an isolated regression case remains row-denied for non-bypass roles |
| Bypass role | service_role still lacks all commerce ACLs; do not expect RLS to constrain its bypass attribute |
| API residuals | No table/column privilege, including TRUNCATE/REFERENCES/TRIGGER/MAINTAIN, on the explicit 23 targets |
| History | Runtime cannot read, insert, update, delete or truncate _prisma_migrations |
| DDL/escalation | Deny permanent CREATE/ALTER/DROP, ownership changes and SET ROLE to privileged/API roles; assess inherited TEMPORARY as deferred |
| Prisma | Real create/update/upsert, nested writes, RETURNING and transaction behavior, including updated_at writes and duplicate handling |
| Locks | Lock mutable aggregate roots; do not add UPDATE to immutable rows merely to satisfy row-lock requirements |
| Defaults | Future postgres-created test tables/sequences receive no runtime/API grants; unrelated creators/objects are unchanged |
| Future functions | Test explicit per-function execution revocation in the creation transaction; no global default change |
| Abort/recovery | Existing unsafe role, unexpected policy/owner/global grants and partial-stage failure stop safely; 02 rolls back atomically |

Actual shared-pooler authentication, managed-service compatibility and upstream certificate policy cannot be certified by the disposable local instance. They require separately authorized B.2 checks against the configured project. No permission test is performed by running DML with the current privileged postgres identity and assuming it represents runtime access.

## Approved B.2 sequence after isolated tests pass

1. Repeat fresh target/TLS/access preflight and snapshot capture; confirm exact owner-approved file checksums.
2. Execute only reviewed `01-create-runtime-role.sql` through the controlled owner connection. It creates NOLOGIN without password or memberships. PostgreSQL may record the creator's administrative relationship to the new role; this does not authorize a membership from runtime to postgres.
3. Execute `02-apply-runtime-access.sql` in its existing transaction. It preserves owners, revokes only the explicitly named existing objects, installs creator/schema-scoped future defaults and enables 66 policies. If any statement fails, stop. Do not drop existing policies, add CASCADE, broaden grants or automatically retry edited SQL.
4. Capture post-apply state and execute `03-verify-runtime-access.sql` read-only. Check exact column permissions, policies/predicates, ownership, memberships, default privileges and denied history/API access. Its allowed login state must be checked against the current deployment stage.
5. Provision a strong independent runtime password through the approved secret system. No password belongs in SQL source, logs, command arguments, history or this runbook. Do not rotate postgres automatically.
6. Prepare the separate ignored CLI environment from `.env.migrations.example`; move DIRECT_URL only after approval. Keep runtime .env.local with DATABASE_URL and runtime integration keys only. Remove migration keys from every runtime-loaded file, parent environment and deploy-secret set.
7. Activate the isolated CLI entry point only after that file/secret binding exists. The prepared command path is `--config prisma.migrations.config.ts`; after the successful cutover replace the legacy prisma.config.ts loader with the isolated implementation or an explicit re-export so no default CLI path keeps reading runtime files. Do not fall back to DATABASE_URL or silently keep a mixed-file fallback. Validate/generate/build continue to use the offline config.
8. Enable the login only after grants/policies/password and deployment isolation are approved and verified. Confirm custom-role session/transaction authentication before the API cutover. DATABASE_URL uses the custom runtime username with the same project suffix/transaction endpoint; DIRECT_URL retains the controlled owner/session identity. Preserve working CA settings exactly; pg uses sslrootcert/verify-full and the CLI engine uses sslcert/require/strict.
9. Switch runtime credentials, recycle API pools/processes and perform bounded allowed/denied checks using actual new credentials. Verify current_user/role flags, representative model access, TLS and upstream state within the same transaction. Run migration status through the isolated owner CLI and verify checksum/history unchanged. Do not insert business/seed data as a connectivity check.
10. Re-capture ACL/policy state, verify no new object ownership or API access, and record the cutover outcome. A NOLOGIN role, unverified pooler password, lingering migration secret in the runtime deployment or failed policy/Prisma test blocks cutover.

## Runtime deployment isolation

Nest now allowlists runtime configuration and ignores migration keys in the legacy file without editing it. It refuses inherited migration URL variables, disables ConfigService's process-env fallback and does not populate process.env from files. Runtime still uses its current DATABASE_URL identity until B.2. Do not mistake this compatibility filtering for completed database-role separation.

The prepared isolated CLI config reads only shell > .env.migrations.local > .env.migrations. The current default CLI config remains a clearly documented legacy compatibility path until B.2. Offline build/test commands use prisma.offline.config.ts and need neither secret file.

In production, use separate migration/runtime jobs and identities. The API artifact should contain compiled runtime code and production dependencies only; exclude Prisma CLI/config/security tooling, migration secret files and privileged secret-store access. Supply the public CA through a read-only trust-file mount. `.dockerignore` is a build-context safeguard, not proof of deployment isolation. Scan the actual image/artifact and inspect runtime secret bindings before approval.

Separate local files do not isolate two processes running as the same OS account. The compatibility loader temporarily reads an allowlisted projection of a legacy mixed file, whose bytes remain readable to that account. Owner approval must address this local-development limitation. No filesystem ACL, hosting identity, container or system-wide security setting is created by B.1.

## Rollback and recovery

- Before changes, capture exact environment-specific ACLs, grantors/options, column ACLs, default privileges, policy definitions and ownership. Capture a known-good **secure** state after successful hardening. Do not commit snapshots or capture credentials/password hashes.
- If 01 succeeds and 02 fails, leave the runtime NOLOGIN and stop. The transaction protects 02's changes; investigate with read-only inspection. Do not automatically delete the role or alter migration history.
- On cutover failure, stop runtime traffic and drain/close only the affected runtime clients under the approved operational plan. Do not restart NestJS with postgres credentials.
- Restore or forward-fix only a reviewed secure allowlist/policy revision, using the captured state to identify exact differences. A first cutover has no previous least-privilege deployment: remain stopped until a reviewed fix passes, rather than restoring the insecure baseline.
- Never replay preflight ACLs blindly: they include unnecessary API-facing privileges. Keep those revoked, keep history inaccessible and preserve approved RLS. Do not weaken certificate/hostname validation or remove CA verification to restore availability.
- Restore runtime application/configuration versions only with the dedicated runtime secret and the isolated CLI path. Verify both allowed and denied operations again, then re-capture state. Any emergency exception requires new owner approval.
- Ownership remains postgres, so owner access remains the controlled recovery path. Never use reset, DROP OWNED, REASSIGN OWNED, destructive recovery, broad GRANT ALL or an automatic rollback SQL template.

## Future changes and deferred limitations

Every future application table must explicitly add its approved grants and command policies in the same reviewed security/migration change. Do not automatically apply this manifest to all public objects or grant runtime access to future Prisma bookkeeping. Defaults follow the actual creator; a future migration-owner change needs a new plan. Future application functions must revoke PUBLIC/API execution in their creation transaction; a schema-only default revoke cannot remove global PUBLIC EXECUTE.

PUBLIC TEMPORARY and global function defaults remain unchanged. Runtime has no permanent application DDL; inherited temporary-table creation remains a documented exception. Staff role provisioning, expiry extensions, historical purge/correction, Auth/Storage policies, production backups/rotation/auditing and ownership redesign remain separate work. No Part B.1 artifact authorizes any of those changes.
