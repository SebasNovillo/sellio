import { fileURLToPath } from 'node:url';
import type { ConfigModuleOptions } from '@nestjs/config';
import { validateEnvironment } from './environment.js';
import { readEnvironmentFiles } from './environment-files.js';

const runtimeKeys = [
  'NODE_ENV', 'PORT', 'API_DOCS_ENABLED', 'DATABASE_URL',
  'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY',
  'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET',
] as const;

export function runtimeConfigurationOptions(
  directory = fileURLToPath(new URL('../../', import.meta.url)),
  environment: NodeJS.ProcessEnv = process.env,
): ConfigModuleOptions {
  // A process already given a migration secret must not operate as the API.
  if (environment.DIRECT_URL || environment.DATABASE_MIGRATION_URL) {
    throw new Error('Migration credentials must not be supplied to the API process.');
  }
  const configuration = validateEnvironment(readEnvironmentFiles(
    directory, ['.env.local', '.env'], runtimeKeys, environment,
  ));
  return {
    isGlobal: true,
    ignoreEnvFile: true,
    ignoreEnvVars: true,
    skipProcessEnv: true,
    load: [() => configuration],
  };
}
