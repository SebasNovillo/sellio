import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { Socket } from 'node:net';
import { mock, test } from 'node:test';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { validateEnvironment } from '../dist/config/environment.js';
import { PrismaService } from '../dist/infrastructure/database/prisma.service.js';
import { Prisma } from '../dist/generated/prisma/client.js';
import * as enums from '../dist/generated/prisma/enums.js';

test('the generated client exposes all 22 domain models and 13 enums', () => {
  assert.deepEqual(Object.values(Prisma.ModelName).sort(), [
    'User', 'Address', 'Brand', 'Category', 'Product', 'ProductCategory', 'ProductImage',
    'ProductOption', 'ProductOptionValue', 'ProductVariant', 'VariantOptionValue',
    'InventoryItem', 'InventoryReservation', 'InventoryMovement', 'Cart', 'CartItem',
    'CheckoutAttempt', 'Order', 'OrderItem', 'OrderAddress', 'Payment', 'PaymentEvent',
  ].sort());
  assert.equal(Object.keys(enums).length, 13);
});

test('database configuration rejects invalid URLs without exposing credentials', () => {
  assert.throws(() => validateEnvironment({ DATABASE_URL: '' }), /valid PostgreSQL/);
  assert.throws(() => validateEnvironment({ DATABASE_URL: 'https://example.test' }), /valid PostgreSQL/);
  assert.throws(() => validateEnvironment({ DATABASE_URL: 123 }), /valid PostgreSQL/);
  const url = 'postgresql://placeholder:placeholder@127.0.0.1:1/sellio';
  assert.deepEqual(validateEnvironment({ DATABASE_URL: url }), {
    DATABASE_URL: url,
    PORT: 4000,
    NODE_ENV: 'development',
    API_DOCS_ENABLED: true,
  });
});

test('Prisma infrastructure constructs and shuts down without any TCP connection', async () => {
  const connect = mock.method(Socket.prototype, 'connect', () => {
    throw new Error('This offline test must never open a connection.');
  });
  try {
    const prisma = new PrismaService(new ConfigService({
      DATABASE_URL: 'postgresql://placeholder:placeholder@127.0.0.1:1/sellio',
      DIRECT_URL: 'postgresql://placeholder:placeholder@127.0.0.1:2/sellio',
    }));
    await prisma.onModuleDestroy();
    assert.equal(connect.mock.callCount(), 0);
    assert.throws(() => new PrismaService(new ConfigService({
      DIRECT_URL: 'postgresql://placeholder:placeholder@127.0.0.1:2/sellio',
    })), /DATABASE_URL/);
  } finally {
    connect.mock.restore();
  }
});

test('Prisma CLI selects only DIRECT_URL and never falls back to runtime or legacy URLs', () => {
  const configUrl = new URL('../prisma.config.ts', import.meta.url).href;
  for (const directUrl of ['', 'postgresql://placeholder:placeholder@127.0.0.1:2/sellio']) {
    const result = spawnSync(process.execPath, ['--experimental-strip-types', '--input-type=module', '-e', `
      import { Socket } from 'node:net';
      Socket.prototype.connect = () => { throw new Error('TCP prohibited in offline config test'); };
      const { default: config } = await import(${JSON.stringify(configUrl)});
      process.stdout.write(JSON.stringify(config.datasource.url ?? null));
    `], {
      encoding: 'utf8',
      env: {
        ...process.env,
        DIRECT_URL: directUrl,
        DATABASE_URL: 'postgresql://placeholder:placeholder@127.0.0.1:1/sellio',
        DATABASE_MIGRATION_URL: 'postgresql://placeholder:placeholder@127.0.0.1:3/sellio',
      },
    });
    assert.equal(result.status, 0, 'Offline config subprocess must succeed.');
    assert.equal(JSON.parse(result.stdout), directUrl || null);
  }
});

test('the pinned PostgreSQL adapter sends unnamed queries for transaction pooler compatibility', async () => {
  const connect = mock.method(Socket.prototype, 'connect', () => {
    throw new Error('This offline test must never open a connection.');
  });
  const adapter = await new PrismaPg({
    connectionString: 'postgresql://placeholder:placeholder@127.0.0.1:1/sellio',
  }).connect();
  const query = mock.method(adapter.underlyingDriver(), 'query', (...args: unknown[]) => {
    assert.equal((args[0] as { name?: string }).name, undefined);
    return Promise.resolve({ rows: [], fields: [], rowCount: 0 });
  });
  try {
    await adapter.queryRaw({ sql: 'SELECT 1', args: [], argTypes: [] });
    assert.equal(query.mock.callCount(), 1);
    assert.equal(connect.mock.callCount(), 0);
  } finally {
    query.mock.restore();
    await adapter.dispose();
    connect.mock.restore();
  }
});
