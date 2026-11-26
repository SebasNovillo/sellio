# Database

The approved architecture includes **22 entities**, with CheckoutAttempt separate from Payment. The unchanged initial migration, including all 13 enums and custom PostgreSQL constraints, was applied and verified in sellio-dev on 2026-11-23. Application tables are empty; future database changes require separate approval.

- [Database design](Sellio_DATABASE_DESIGN.md)
- [Implementation specification and Prisma plan](DATABASE_IMPLEMENTATION_SPEC.md)
- [Canonical ERD](ERD.md)
- [Initial migration application, verified inventory and remaining security work](initial-migration-verification.md)
- [Part A foundation, environment, offline checks and custom migration SQL](PRISMA_FOUNDATION.md)
- [Accepted CheckoutAttempt entity decision](../decisions/ADR-010-checkout-attempt.md)
- [Database access hardening implementation record (prepared only)](database-access-security.md)
- [Security deployment, isolated testing and rollback runbook](database-access-runbook.md)
- [Accepted runtime access design](../decisions/ADR-011-database-access.md)

PostgreSQL and Prisma 7.10.1 are the persistence stack. Schema validation, client generation, type checks and builds require no database. The API requires DATABASE_URL to configure its lazy client, but does not connect until a query is requested.

`apps/api/.env.example` documents runtime DATABASE_URL; `.env.migrations.example` documents the prepared isolated CLI DIRECT_URL configuration. Runtime configuration filters migration keys without changing existing local files. The default CLI loader remains a legacy compatibility path until the separately approved B.2 cutover. See [Supabase connections](SUPABASE_CONNECTIONS.md) and the security runbook for the transaction/session pooler split and approval boundaries. Seed data, business services and database-backed tests are deferred.
