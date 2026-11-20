export function validateEnvironment(environment: Record<string, unknown>) {
  const port = Number(environment.PORT ?? 4000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  const nodeEnv = environment.NODE_ENV ?? 'development';
  if (!['development', 'test', 'production'].includes(String(nodeEnv))) {
    throw new Error('NODE_ENV must be development, test, or production.');
  }

  const docsEnabled = environment.API_DOCS_ENABLED ?? (nodeEnv === 'production' ? 'false' : 'true');
  if (docsEnabled !== 'true' && docsEnabled !== 'false') {
    throw new Error('API_DOCS_ENABLED must be true or false.');
  }

  if (environment.DATABASE_URL !== undefined) {
    try {
      if (typeof environment.DATABASE_URL !== 'string') throw new Error();
      const databaseUrl = new URL(environment.DATABASE_URL);
      if (!['postgresql:', 'postgres:'].includes(databaseUrl.protocol) || !databaseUrl.hostname) {
        throw new Error();
      }
    } catch {
      throw new Error('DATABASE_URL must be a valid PostgreSQL connection URL.');
    }
  }

  return { ...environment, PORT: port, NODE_ENV: nodeEnv, API_DOCS_ENABLED: docsEnabled === 'true' };
}
