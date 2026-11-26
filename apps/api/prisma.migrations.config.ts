import { fileURLToPath } from 'node:url';
import { defineConfig } from 'prisma/config';
import { readEnvironmentFiles } from './src/config/environment-files.ts';

// Prepared isolated CLI entry point. Activate only after the approved B.2 cutover.
// Never reads the API's .env / .env.local and never falls back to DATABASE_URL.
const environment = readEnvironmentFiles(
  fileURLToPath(new URL('./', import.meta.url)),
  ['.env.migrations.local', '.env.migrations'],
  ['DIRECT_URL'],
  process.env,
);

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: environment.DIRECT_URL || undefined },
});
