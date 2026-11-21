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
  // CLI operations use the session pooler only; never fall back to the runtime URL.
  // Missing/blank DIRECT_URL still permits offline validation and generation.
  datasource: { url: process.env.DIRECT_URL || undefined },
});
