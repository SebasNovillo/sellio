import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { Socket } from 'node:net';
import { dirname, join } from 'node:path';
import { mock, test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { readEnvironmentFiles } from '../dist/config/environment-files.js';
import { runtimeConfigurationOptions } from '../dist/config/runtime-environment.js';

const apiRoot = fileURLToPath(new URL('../', import.meta.url));
const fixtureRoot = realpathSync(join(apiRoot, '.test-build'));
const runtimeUrl = 'postgresql://fixture:fixture@127.0.0.1:1/sellio?sslmode=verify-full&sslrootcert=C%3A%2Ffixture%2Fca.crt';
// Never include the inherited process environment in assertion diffs.
const environmentFingerprint = () => createHash('sha256')
  .update(JSON.stringify(Object.entries(process.env).sort(([a], [b]) => a.localeCompare(b))))
  .digest('hex');

function fixture() {
  const directory = mkdtempSync(join(fixtureRoot, 'environment-'));
  return {
    directory,
    write(name: string, value: string) { writeFileSync(join(directory, name), value); },
    close() {
      // Verify the resolved target remains an immediate generated workspace child.
      assert.equal(dirname(realpathSync(directory)), fixtureRoot);
      rmSync(directory, { recursive: true, force: true });
    },
  };
}

test('environment files preserve shell > local > base precedence without process mutation', () => {
  const files = fixture();
  try {
    files.write('.env', 'PORT=4100\nNODE_ENV=test\nDATABASE_URL=base\nDIRECT_URL=base-private\n');
    files.write('.env.local', `PORT=4200\nDATABASE_URL="${runtimeUrl}"\nDIRECT_URL=local-private\n`);
    const shell = { PORT: '4300' };
    const before = environmentFingerprint();
    const values = readEnvironmentFiles(files.directory, ['.env.local', '.env'], ['PORT', 'NODE_ENV', 'DATABASE_URL'], shell);
    assert.deepEqual(values, { PORT: '4300', NODE_ENV: 'test', DATABASE_URL: runtimeUrl });
    assert.deepEqual(shell, { PORT: '4300' });
    assert.equal(environmentFingerprint(), before, 'Process environment must not be mutated.');
    assert.equal(readEnvironmentFiles(files.directory, ['missing'], ['DIRECT_URL'], { DIRECT_URL: '' }).DIRECT_URL, '');
  } finally { files.close(); }
});

test('runtime accepts the existing mixed-file layout while dropping migration and unknown keys', async () => {
  const files = fixture();
  const connect = mock.method(Socket.prototype, 'connect', () => { throw new Error('TCP prohibited.'); });
  try {
    files.write('.env.local', `DATABASE_URL="${runtimeUrl}"\nDIRECT_URL=must-not-load\nDATABASE_MIGRATION_URL=legacy-private\nUNRECOGNIZED=ignored\nPORT=4100\n`);
    files.write('.env.migrations.local', 'DIRECT_URL=must-not-read\nDATABASE_URL=wrong\n');
    const original = readFileSync(join(files.directory, '.env.local'), 'utf8');
    const before = environmentFingerprint();
    const options = runtimeConfigurationOptions(files.directory, {});
    const app = await NestFactory.createApplicationContext({
      module: class ConfigurationHarness {}, imports: [ConfigModule.forRoot(options)],
    }, { logger: false });
    try {
      const configuration = app.get(ConfigService);
      assert.equal(configuration.get('DATABASE_URL'), runtimeUrl);
      assert.equal(configuration.get('PORT'), 4100);
      assert.equal(configuration.get('API_DOCS_ENABLED'), true);
      assert.ok(configuration.get('DIRECT_URL') === undefined, 'Migration URL must not be available.');
      assert.ok(configuration.get('DATABASE_MIGRATION_URL') === undefined, 'Legacy migration URL must not be available.');
      assert.equal(configuration.get('UNRECOGNIZED'), undefined);
      assert.equal(options.skipProcessEnv, true);
      assert.equal(environmentFingerprint(), before, 'Process environment must not be mutated.');
      assert.equal(readFileSync(join(files.directory, '.env.local'), 'utf8'), original);
      assert.equal(connect.mock.callCount(), 0);
    } finally { await app.close(); }
  } finally { connect.mock.restore(); files.close(); }
});

test('runtime refuses inherited migration secrets with a sanitized startup error', () => {
  const secret = 'synthetic-sensitive-value';
  for (const key of ['DIRECT_URL', 'DATABASE_MIGRATION_URL']) {
    assert.throws(() => runtimeConfigurationOptions(fixtureRoot, { [key]: secret }), error => {
      assert.ok(error instanceof Error);
      assert.equal(error.message, 'Migration credentials must not be supplied to the API process.');
      assert.equal(error.message.includes(secret), false);
      return true;
    });
  }
});

test('runtime applies production defaults and preserves strict TLS URL bytes', async () => {
  const options = runtimeConfigurationOptions(fixtureRoot, { NODE_ENV: 'production', DATABASE_URL: runtimeUrl });
  assert.equal(options.ignoreEnvFile, true);
  assert.equal(options.ignoreEnvVars, true);
  const factory = options.load?.[0];
  assert.equal(typeof factory, 'function');
  if (typeof factory !== 'function') throw new Error('Missing runtime configuration factory.');
  const values = await factory();
  assert.equal(values.DATABASE_URL, runtimeUrl);
  assert.equal(values.API_DOCS_ENABLED, false);
  assert.equal(values.DIRECT_URL, undefined);
});

test('prepared migration CLI uses only its separate files and never runtime or legacy URLs', () => {
  const files = fixture();
  try {
    copyFileSync(join(apiRoot, 'prisma.migrations.config.ts'), join(files.directory, 'prisma.migrations.config.ts'));
    mkdirSync(join(files.directory, 'src/config'), { recursive: true });
    copyFileSync(join(apiRoot, 'src/config/environment-files.ts'), join(files.directory, 'src/config/environment-files.ts'));
    files.write('.env.local', `DIRECT_URL=runtime-private\nDATABASE_URL=${runtimeUrl}\n`);
    files.write('.env', 'DIRECT_URL=base-runtime-private\n');
    const configUrl = pathToFileURL(join(files.directory, 'prisma.migrations.config.ts')).href;
    function load(environment: NodeJS.ProcessEnv) {
      const child = spawnSync(process.execPath, ['--experimental-strip-types', '--input-type=module', '-e', `
        import { Socket } from 'node:net';
        Socket.prototype.connect = () => { throw new Error('TCP prohibited.'); };
        const { default: config } = await import(${JSON.stringify(configUrl)});
        process.stdout.write(JSON.stringify(config.datasource.url ?? null));
      `], { encoding: 'utf8', timeout: 10000, env: {
        ...process.env, DIRECT_URL: '', DATABASE_URL: runtimeUrl, DATABASE_MIGRATION_URL: 'legacy-private', ...environment,
      } });
      assert.equal(child.status, 0, 'Offline migration config subprocess must succeed.');
      return JSON.parse(child.stdout) as string | null;
    }
    assert.equal(load({}), null);
    files.write('.env.migrations', 'DIRECT_URL=base-migrator\n');
    files.write('.env.migrations.local', 'DIRECT_URL=local-migrator\n');
    // Remove the inherited override in this test to exercise file precedence.
    assert.equal(load({ DIRECT_URL: undefined }), 'local-migrator');
    assert.equal(load({ DIRECT_URL: 'shell-migrator' }), 'shell-migrator');
    assert.equal(load({ DIRECT_URL: '' }), null);
  } finally { files.close(); }
});
