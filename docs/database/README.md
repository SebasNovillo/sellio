# Database

The approved architecture includes **22 entities**, with CheckoutAttempt separate from Payment. Part A implements the documented Prisma contracts and lazy NestJS infrastructure. No migration has been generated/applied or database connected; unresolved details and PostgreSQL SQL still require migration review.

- [Database design](Sellio_DATABASE_DESIGN.md)
- [Implementation specification and Prisma plan](DATABASE_IMPLEMENTATION_SPEC.md)
- [Canonical ERD](ERD.md)
- [Part A foundation, environment, offline checks and future migration SQL](PRISMA_FOUNDATION.md)
- [Accepted CheckoutAttempt entity decision](../decisions/ADR-010-checkout-attempt.md)

PostgreSQL and Prisma 7.10.1 are the persistence stack. Schema validation, client generation, type checks and builds require no database. The API requires DATABASE_URL to configure its lazy client, but does not connect until a query is requested.

`apps/api/.env.example` documents runtime DATABASE_URL and optional DATABASE_MIGRATION_URL. Keep both server-side. Select/provision approved PostgreSQL and review the complete migration plus custom SQL in a separately authorized task. Seed data, business services and database-backed tests are deferred.
