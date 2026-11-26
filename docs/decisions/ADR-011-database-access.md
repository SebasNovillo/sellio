# ADR-011: Backend database access hardening

- Date: 2026-11-25
- Status: Accepted design; repository preparation only, not applied to sellio-dev
- Scope: Part A approvals and Part B.1 preparation

## Context

The initial 22-table migration is applied. Both configured pooler URLs currently use the privileged postgres identity. NestJS is the exclusive business-data access layer; Supabase Auth and Storage remain separate planned integrations. Endpoint separation alone does not provide least-privilege access.

## Decision

Retain postgres as the controlled V1 migration/maintenance owner and preserve application object ownership. Prepare a non-owner sellio_runtime role, initially NOLOGIN, without role memberships, superuser, database/role creation, replication or RLS bypass privileges. Activation and credential cutover require separate approval.

Adopt the approved matrix: SELECT/INSERT on 22 tables, column-level UPDATE on 17, DELETE on five, and 66 command-specific RLS policies addressed only to sellio_runtime. User INSERT must have CUSTOMER role; runtime cannot update roles or authentication identities. Historical financial snapshots, immutable identities and inventory movements remain protected by the column allowlists and deletion restrictions. Runtime and API-facing roles receive no Prisma history access. Revoke residual privileges only on the explicitly listed application/history objects.

RLS provides backend-wide access within these grants. NestJS must enforce customer ownership and business authorization. Do not represent these policies as per-customer isolation. Keep service_role subject to application-table privilege removal despite its RLS bypass attribute.

Prepare separate runtime and migration loaders, secret files and deployment identities. Preserve strict CA and hostname verification. Maintain the working private configuration until an approved cutover; the legacy default CLI path remains explicitly documented in B.1. Production runtime artifacts and secret bindings must exclude migration credentials.

Harden postgres-created future table/sequence defaults in public. Those defaults cannot be filtered by table name; unrelated future objects need explicit review and application objects need explicit grants/policies. Abort if global defaults or inherited grants prevent the intended boundary.

## Consequences and deferred decisions

SQL execution, isolated database provisioning/testing, custom-role pooler login and runtime cutover require Part B.2 approval. Data API disablement is approved in principle, subject to Auth/Storage dependency checks and separately authorized Dashboard work.

PUBLIC TEMPORARY, global PUBLIC EXECUTE defaults, ownership transfers, a new migration-owner role, managed schemas/roles, staff provisioning and historical cleanup remain deferred. Future application functions must revoke unnecessary PUBLIC/API execution in their creation transaction. Separate local files under one OS identity are not a complete security boundary. Database-wide runtime access still requires trustworthy backend authorization.

See the [implementation record](../database/database-access-security.md) for the complete matrix and SQL inventory, and the [operational runbook](../database/database-access-runbook.md) for snapshots, isolated tests, deployment and fail-closed recovery. The applied initial migration remains unchanged.
