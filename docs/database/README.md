# Database

The approved architecture includes **22 entities**, with CheckoutAttempt separate from Payment. Detailed field, constraint and lifecycle proposals are not yet approved for migrations.

- [Database design](Sellio_DATABASE_DESIGN.md)
- [Implementation specification and Prisma plan](DATABASE_IMPLEMENTATION_SPEC.md)
- [Canonical ERD](ERD.md)
- [Accepted CheckoutAttempt entity decision](../decisions/ADR-010-checkout-attempt.md)

PostgreSQL and Prisma are the planned persistence stack. No schema, migrations, ORM dependency, or running database is required by the initial scaffold.

`apps/api/.env.example` reserves `DATABASE_URL`. A future database task will define the supported PostgreSQL version, Prisma setup, local provisioning, schema, migration workflow, and seed strategy. Do not put database credentials in a frontend environment file.
