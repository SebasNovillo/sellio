import assert from 'node:assert/strict';
import { Socket } from 'node:net';
import { mock, test } from 'node:test';
import { ConfigService } from '@nestjs/config';
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
    }));
    await prisma.onModuleDestroy();
    assert.equal(connect.mock.callCount(), 0);
    assert.throws(() => new PrismaService(new ConfigService({})), /DATABASE_URL/);
  } finally {
    connect.mock.restore();
  }
});
