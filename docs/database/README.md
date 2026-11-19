# Database

PostgreSQL and Prisma are the planned persistence stack. No schema, migrations, ORM dependency, or running database is required by the initial scaffold.

`apps/api/.env.example` reserves `DATABASE_URL`. A future database task will define the supported PostgreSQL version, Prisma setup, local provisioning, schema, migration workflow, and seed strategy. Do not put database credentials in a frontend environment file.
