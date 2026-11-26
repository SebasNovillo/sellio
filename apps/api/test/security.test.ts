import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

interface TableAccess { name: string; insertCheck: string; update: string[]; delete: boolean }
interface AccessManifest {
  runtimeRole: string; ownerRole: string; schema: string; historyTable: string;
  initialMigration: string; initialMigrationSha256: string; apiRoles: string[]; tables: TableAccess[];
}
const base = new URL('../prisma/security/', import.meta.url);
const read = (name: string) => readFileSync(new URL(name, base), 'utf8');
const manifest = JSON.parse(read('access-manifest.json')) as AccessManifest;
const schema = readFileSync(new URL('../prisma/schema.prisma', import.meta.url), 'utf8');
const initial = readFileSync(new URL('../prisma/migrations/20261120000000_initial/migration.sql', import.meta.url));
const application = read('02-apply-runtime-access.sql');
const creation = read('01-create-runtime-role.sql');
const verifier = read('03-verify-runtime-access.sql');
const snapshot = read('00-capture-state.sql');
const noComments = (text: string) => text.replace(/--[^\r\n]*/g, '');
const quoted = (text: string) => [...text.matchAll(/"([^"]+)"/g)].map(m => m[1]);
const models = new Map([...schema.matchAll(/^model \w+ \{([\s\S]*?)^\}/gm)].map(m => {
  const name = m[1].match(/@@map\("([^"]+)"\)/)?.[1];
  assert.ok(name);
  return [name, m[1]];
}));

test('security scope matches the approved 22-table baseline, 17 mutable tables and five deletion targets', () => {
  assert.equal(manifest.runtimeRole, 'sellio_runtime');
  assert.equal(manifest.ownerRole, 'postgres');
  assert.equal(manifest.historyTable, '_prisma_migrations');
  assert.equal(manifest.tables.length, 22);
  assert.deepEqual(manifest.tables.map(t => t.name).sort(), [...models.keys()].sort());
  assert.equal(manifest.tables.filter(t => t.update.length).length, 17);
  assert.deepEqual(manifest.tables.filter(t => t.delete).map(t => t.name).sort(),
    ['address', 'cart_item', 'product_category', 'product_image', 'variant_option_value']);
  assert.equal(createHash('sha256').update(initial).digest('hex'), manifest.initialMigrationSha256);
  assert.equal(manifest.initialMigrationSha256, '00e9084376d3d894acd2575dcc5999db2286b206b5eafd297a49cae35a5515b6');
});

test('every update column exists in both Prisma and the reviewed SQL; historical core remains frozen', () => {
  const protectedColumns: Record<string, string[]> = {
    user: ['role', 'auth_id'],
    checkout_attempt: ['user_id', 'cart_id', 'cart_revision', 'idempotency_key', 'request_fingerprint', 'fingerprint_version', 'request_snapshot'],
    order: ['order_number', 'user_id', 'source_cart_id', 'currency', 'subtotal', 'shipping_total', 'tax_total', 'discount_total', 'grand_total', 'tax_details_snapshot', 'shipping_method_snapshot'],
    payment: ['order_id', 'provider', 'amount', 'currency'],
    payment_event: ['provider', 'provider_event_id', 'provider_object_id', 'event_type', 'received_at'],
    inventory_reservation: ['inventory_item_id', 'checkout_attempt_id', 'order_id', 'quantity', 'expires_at'],
  };
  for (const table of manifest.tables) {
    const model = models.get(table.name);
    assert.ok(model);
    const fields = new Set([...model.matchAll(/^\s+(\w+)\s+[^\r\n]+/gm)]
      .map(m => m[0].match(/@map\("([^"]+)"\)/)?.[1] ?? m[1]));
    const tableSql = initial.toString().match(new RegExp(`CREATE TABLE "${table.name}" \\(([\\s\\S]*?)\\n\\);`))?.[1];
    assert.ok(tableSql);
    for (const column of table.update) {
      assert.ok(fields.has(column), `${table.name}.${column} missing from Prisma`);
      assert.ok(tableSql.includes(`"${column}" `), `${table.name}.${column} missing from migration`);
      assert.ok(!['id', 'created_at', ...(protectedColumns[table.name] ?? [])].includes(column));
    }
  }
  for (const name of ['order_item', 'order_address', 'inventory_movement']) {
    const table = manifest.tables.find(t => t.name === name);
    assert.ok(table);
    assert.deepEqual(table.update, []);
    assert.equal(table.delete, false);
  }
});

test('explicit grants and revocations match the matrix without schema-wide existing-object revokes', () => {
  const grant = application.match(/GRANT SELECT, INSERT ON TABLE\s+([\s\S]+?)TO sellio_runtime;/);
  assert.ok(grant);
  assert.deepEqual(quoted(grant[1]).sort(), manifest.tables.map(t => t.name).sort());
  const updates = [...application.matchAll(/GRANT UPDATE \(([^)]+)\) ON TABLE public\."([^"]+)" TO sellio_runtime;/g)]
    .map(m => ({ table: m[2], columns: quoted(m[1]) }));
  assert.deepEqual(updates, manifest.tables.filter(t => t.update.length).map(t => ({ table: t.name, columns: t.update })));
  const deletes = [...application.matchAll(/GRANT DELETE ON TABLE public\."([^"]+)" TO sellio_runtime;/g)].map(m => m[1]);
  assert.deepEqual(deletes, manifest.tables.filter(t => t.delete).map(t => t.name));
  const revokes = [...application.matchAll(/REVOKE ALL PRIVILEGES ON TABLE public\."([^"]+)" FROM ([^;]+);/g)];
  assert.deepEqual(revokes.map(m => m[1]), [...manifest.tables.map(t => t.name), manifest.historyTable]);
  for (const revoke of revokes) assert.deepEqual(revoke[2].split(', '), ['PUBLIC', ...manifest.apiRoles, manifest.runtimeRole]);
  assert.doesNotMatch(noComments(application), /ON ALL TABLES IN SCHEMA|GRANT UPDATE ON|GRANT ALL|OWNER TO/i);
});

test('66 command-specific policies enforce CUSTOMER insertion and provide no history or PUBLIC policy', () => {
  const policies = [...application.matchAll(/^CREATE POLICY (\w+) ON public\."([^"]+)" FOR (SELECT|INSERT|UPDATE|DELETE) TO (\w+) ([^\r\n]+);$/gm)];
  assert.equal(policies.length, 66);
  assert.deepEqual(policies.reduce<Record<string, number>>((counts, m) => ({ ...counts, [m[3]]: (counts[m[3]] ?? 0) + 1 }), {}),
    { SELECT: 22, INSERT: 22, UPDATE: 17, DELETE: 5 });
  const enabled = [...application.matchAll(/ALTER TABLE public\."([^"]+)" ENABLE ROW LEVEL SECURITY;/g)].map(m => m[1]);
  assert.deepEqual(enabled, manifest.tables.map(t => t.name));
  for (const table of manifest.tables) {
    const actual = policies.filter(p => p[2] === table.name);
    assert.deepEqual(actual.map(p => p[3]), ['SELECT', 'INSERT', ...(table.update.length ? ['UPDATE'] : []), ...(table.delete ? ['DELETE'] : [])]);
    for (const policy of actual) assert.equal(policy[4], manifest.runtimeRole);
    assert.equal(actual.find(p => p[3] === 'INSERT')?.[5], `WITH CHECK (${table.insertCheck})`);
  }
  assert.equal(manifest.tables.find(t => t.name === 'user')?.insertCheck, "role = 'CUSTOMER'::public.user_role");
  assert.match(schema, /enum UserRole \{\s+CUSTOMER/);
  assert.ok(initial.toString().includes("CREATE TYPE \"user_role\" AS ENUM ('CUSTOMER', 'MANAGER', 'ADMIN')"));
  assert.ok(policies.every(p => p[2] !== manifest.historyTable));
  assert.doesNotMatch(noComments(application), /FOR ALL|TO PUBLIC|FORCE ROW LEVEL/);
});

test('role stays NOLOGIN; membership, ownership, baseline and existing-policy gates fail closed', () => {
  assert.match(creation, /CREATE ROLE sellio_runtime\s+NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE\s+NOREPLICATION NOBYPASSRLS;/);
  assert.match(creation, /IF EXISTS[\s\S]+RAISE EXCEPTION/);
  assert.match(application, /NOT rolcanlogin/);
  assert.match(application, /pg_auth_members WHERE member = runtime_oid/);
  assert.match(application, /Existing RLS\/policies need review/);
  assert.match(application, /pg_get_userbyid\(c.relowner\) = 'postgres'/);
  for (const sql of [creation, application]) {
    assert.ok(sql.includes(manifest.initialMigrationSha256));
    assert.doesNotMatch(noComments(sql), /PASSWORD|ALTER ROLE|GRANT sellio_runtime TO|GRANT postgres TO|DROP\s/i);
    assert.match(sql, /BEGIN;/);
    assert.match(sql, /COMMIT;\s*$/);
  }
});

test('defaults affect only future postgres-created public tables/sequences and deferred changes are absent', () => {
  assert.equal([...application.matchAll(/ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public/g)].length, 2);
  assert.match(application, /REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;/);
  assert.match(application, /REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;/);
  assert.doesNotMatch(noComments(application), /REVOKE[^;]+TEMPORARY|REVOKE[^;]+EXECUTE|FOR ROLE supabase_admin|ON (?:SCHEMA|TABLE) (?:auth|storage)\b/i);
});

test('capture and verifier are read-only metadata scripts with bounded queries and no password access', () => {
  for (const sql of [snapshot, verifier]) {
    const tokens = noComments(sql).replace(/'(?:''|[^'])*'/g, "''");
    assert.match(sql, /BEGIN READ ONLY;/);
    assert.match(sql, /SET LOCAL statement_timeout/);
    assert.match(sql, /ROLLBACK;\s*$/);
    assert.doesNotMatch(tokens, /\b(?:CREATE|ALTER|GRANT|REVOKE|INSERT|UPDATE|DELETE|DROP|TRUNCATE)\b/i);
    assert.doesNotMatch(tokens, /pg_authid|rolpassword/i);
  }
  for (const table of manifest.tables) {
    assert.ok(verifier.includes(`('${table.name}', ARRAY[`));
    assert.ok(snapshot.includes(`'${table.name}'`));
  }
  assert.match(verifier, /has_column_privilege/);
  assert.match(verifier, /has_any_column_privilege/);
  assert.match(verifier, /Runtime column access to migration history/);
  assert.match(verifier, /pg_get_expr/);
});
