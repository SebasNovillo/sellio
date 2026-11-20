import { fileURLToPath } from 'node:url';
import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';

// Match Nest's precedence: shell > .env.local > .env, independent of caller cwd.
config({
  path: [
    fileURLToPath(new URL('./.env.local', import.meta.url)),
    fileURLToPath(new URL('./.env', import.meta.url)),
  ],
  quiet: true,
});

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  // Validation and generation need no URL. A future migration must supply one.
  datasource: { url: process.env.DATABASE_MIGRATION_URL ?? process.env.DATABASE_URL },
});
