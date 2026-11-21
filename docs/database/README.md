# Database

The approved architecture includes **22 entities**, with CheckoutAttempt separate from Payment. The initial migration is generated locally with all 13 enums and custom PostgreSQL constraints. It is not applied; no database has been connected. Review the migration and foundation record before separately authorizing PostgreSQL access.

- [Database design](Sellio_DATABASE_DESIGN.md)
- [Implementation specification and Prisma plan](DATABASE_IMPLEMENTATION_SPEC.md)
- [Canonical ERD](ERD.md)
- [Part A foundation, environment, offline checks and future migration SQL](PRISMA_FOUNDATION.md)
- [Accepted CheckoutAttempt entity decision](../decisions/ADR-010-checkout-attempt.md)

PostgreSQL and Prisma 7.10.1 are the persistence stack. Schema validation, client generation, type checks and builds require no database. The API requires DATABASE_URL to configure its lazy client, but does not connect until a query is requested.

`apps/api/.env.example` documents runtime DATABASE_URL and CLI-only DIRECT_URL. Keep both server-side in ignored local environment files. See [Supabase connections](SUPABASE_CONNECTIONS.md) for the transaction/session pooler split and the separately approved connection/migration steps. Seed data, business services and database-backed tests are deferred.
