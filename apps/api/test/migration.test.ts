import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const sql = readFileSync(new URL('../prisma/migrations/20261120000000_initial/migration.sql', import.meta.url), 'utf8');
const schema = readFileSync(new URL('../prisma/schema.prisma', import.meta.url), 'utf8');
const foundation = readFileSync(new URL('../../../docs/database/PRISMA_FOUNDATION.md', import.meta.url), 'utf8');
const compact = (value: string) => value.replace(/\s+/g, '');
const names = (value: string) => [...value.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
const models = new Map([...schema.matchAll(/^model (\w+) \{([\s\S]*?)^\}/gm)].map((match) => {
  const body = match[2];
  const table = body.match(/@@map\("([^"]+)"\)/)?.[1];
  assert.ok(table);
  const columns = new Map([...body.matchAll(/^\s+(\w+)\s+[^\r\n]+/gm)].map((field) => [
    field[1], field[0].match(/@map\("([^"]+)"\)/)?.[1] ?? field[1],
  ]));
  return [match[1], { table, body, columns }];
}));

test('initial SQL covers every mapped table, enum, primary key and Prisma index', () => {
  assert.equal(models.size, 22);
  assert.deepEqual([...sql.matchAll(/^CREATE TABLE "([^"]+)"/gm)].map((match) => match[1]).sort(),
    [...models.values()].map((model) => model.table).sort());
  assert.equal([...sql.matchAll(/PRIMARY KEY \(/g)].length, 22);
  const enumNames = [...schema.matchAll(/^enum \w+ \{([\s\S]*?)^\}/gm)]
    .map((match) => match[1].match(/@@map\("([^"]+)"\)/)?.[1]);
  assert.equal(enumNames.length, 13);
  assert.deepEqual([...sql.matchAll(/^CREATE TYPE "([^"]+)" AS ENUM/gm)].map((match) => match[1]).sort(), enumNames.sort());
  for (const index of schema.matchAll(/@{1,2}(?:unique|index)\([^\r\n]*map: "([^"]+)"/g)) {
    assert.ok(sql.includes(`INDEX "${index[1]}"`), `Missing index ${index[1]}`);
  }
  assert.equal([...sql.matchAll(/^BEGIN;/gm)].length, 1);
  assert.ok(sql.trimEnd().endsWith('COMMIT;'));
  assert.doesNotMatch(sql, /\b(?:DROP|TRUNCATE|DELETE FROM|UPDATE\s+")\b/i);
});

test('all generated foreign keys match schema columns, targets and deletion/update actions', () => {
  const expected: string[] = [];
  for (const model of models.values()) {
    for (const relation of model.body.matchAll(/^\s+\w+\s+(\w+)\??\s+@relation\([^\r\n]*fields: \[([^\]]+)\], references: \[([^\]]+)\], onDelete: (\w+), onUpdate: (\w+)/gm)) {
      const parent = models.get(relation[1]);
      assert.ok(parent);
      const from = relation[2].split(',').map((field) => model.columns.get(field.trim()));
      const to = relation[3].split(',').map((field) => parent.columns.get(field.trim()));
      const action = (value: string) => value.replace('SetNull', 'SET NULL').toUpperCase();
      expected.push(JSON.stringify([model.table, from, parent.table, to, action(relation[4]), action(relation[5])]));
    }
  }
  const actual = [...sql.matchAll(/ALTER TABLE "([^"]+)" ADD CONSTRAINT "[^"]+" FOREIGN KEY \(([^)]+)\) REFERENCES "([^"]+)"\(([^)]+)\) ON DELETE (CASCADE|RESTRICT|SET NULL) ON UPDATE (CASCADE|RESTRICT|SET NULL);/g)]
    .map((match) => JSON.stringify([match[1], names(match[2]), match[3], names(match[4]), match[5], match[6]]));
  assert.equal(expected.length, 35);
  assert.deepEqual(actual.sort(), expected.sort());
  assert.ok(sql.includes('FOREIGN KEY ("accepted_payment_id", "id") REFERENCES "payment"("id", "order_id") ON DELETE RESTRICT'));
});

test('all approved custom SQL is present and preserves financial/cart semantics', () => {
  const blocks = [...foundation.matchAll(/```sql\r?\n([\s\S]*?)```/g)];
  assert.equal(blocks.length, 3);
  for (const block of blocks) assert.ok(compact(sql).includes(compact(block[1])), 'Missing documented custom SQL');
  assert.equal([...sql.matchAll(/CREATE UNIQUE INDEX[^;]+WHERE/g)].length, 7);
  assert.equal([...sql.matchAll(/ADD CONSTRAINT \w+\s+CHECK/g)].length, 14);
  assert.ok(compact(sql).includes('CHECK((user_idISNOTNULL)<>(guest_token_hashISNOTNULL))'));
  assert.ok(sql.includes('"cart_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE RESTRICT'));
  assert.ok(sql.includes('line_total = quantity * unit_price'));
  assert.ok(sql.includes('grand_total = subtotal + shipping_total + tax_total - discount_total'));
  const order = sql.match(/CREATE TABLE "order" \(([\s\S]*?)\n\);/)?.[1] ?? '';
  assert.match(order, /"shipping_total" DECIMAL\(12,2\) NOT NULL DEFAULT 0/);
  assert.match(order, /"tax_total" DECIMAL\(12,2\) NOT NULL DEFAULT 0/);
  const line = sql.match(/CREATE TABLE "order_item" \(([\s\S]*?)\n\);/)?.[1] ?? '';
  assert.match(line, /"tax_total" DECIMAL\(12,2\),/);
  assert.match(line, /"discount_total" DECIMAL\(12,2\),/);
  for (const table of ['address', 'order_address']) {
    const body = sql.match(new RegExp(`CREATE TABLE "${table}" \\(([\\s\\S]*?)\\n\\);`))?.[1] ?? '';
    for (const field of ['line2', 'phone', 'region']) assert.match(body, new RegExp(`"${field}" TEXT,`));
  }
  assert.doesNotMatch(sql, /CREATE UNIQUE INDEX[^;]+ON "?payment"?[^;]+\bstatus\b/i);
});
