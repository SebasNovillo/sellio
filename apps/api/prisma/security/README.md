# Database access preparation

**Prepared, not executed.** These files are operational security SQL, outside Prisma's migrations directory. There is no apply script, install hook or CI database execution. Part B.2 requires separate owner approval, isolated PostgreSQL testing and fresh live preflight/snapshots.

| File | Purpose |
| --- | --- |
| access-manifest.json | Approved 22-table matrix: SELECT/INSERT on 22, UPDATE allowlists on 17, DELETE on five, 66 policies |
| 00-capture-state.sql | Read-only identity, ACL, owner, membership, default and policy snapshots; capture privately |
| 01-create-runtime-role.sql | One-time guarded creation as NOLOGIN with safe attributes; no password, login activation or memberships |
| 02-apply-runtime-access.sql | Explicit grants/revokes, creator/schema-scoped future defaults and 66 RLS policies in one transaction |
| 03-verify-runtime-access.sql | Read-only catalog assertions; does not prove row behavior or pooler authentication |

The mutation files stop on unexpected baseline, owners, role attributes/memberships, global defaults or existing policies. They are deliberately not overwrite/idempotent recovery scripts. File 01 may leave a safe NOLOGIN role if later work stops; never automatically drop it or grant more access to force a retry.

Existing-object changes name only the approved 22 tables and `_prisma_migrations`. No `ALL TABLES IN SCHEMA` revocation is used. Default privileges necessarily affect future objects created by postgres in public; PostgreSQL cannot filter defaults by table name. They grant nothing automatically to runtime/API roles. Future non-Sellio public objects are not automatically treated as application objects and must not be added to the manifest without review.

PUBLIC TEMPORARY, global PUBLIC EXECUTE defaults, managed-role defaults, ownership, Auth/Storage schemas and login/password provisioning remain unchanged. Future application functions must revoke unnecessary execution in the transaction that creates them.

Read the [implementation record](../../../../docs/database/database-access-security.md) and [operational runbook](../../../../docs/database/database-access-runbook.md). The initial migration is immutable. None of these files is a new Prisma migration or evidence of live compatibility.
