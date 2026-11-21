import { defineConfig } from 'prisma/config';

// Never load real credentials or environment files in offline operations.
// Prisma 7.10's schema engine requires a descriptor even for schema-only diffs.
// The loopback placeholder is metadata only: use --from-empty / --to-schema,
// never a *-config-datasource flag with this config.
export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: 'postgresql://offline:offline@127.0.0.1:1/offline' },
});
