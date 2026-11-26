-- PREPARED ONLY. Capture output privately before any approved B.2 change.
-- Metadata only: no role passwords, business rows or migration logs are selected.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT current_database() AS database, current_user AS role, current_schema() AS schema,
  clock_timestamp() AS captured_at, pg_backend_pid() AS backend_pid,
  s.ssl AS upstream_ssl, s.version AS upstream_version, s.cipher AS upstream_cipher
  FROM pg_catalog.pg_stat_ssl s WHERE s.pid = pg_backend_pid();

SELECT c.relname AS object_name, pg_catalog.pg_get_userbyid(c.relowner) AS owner,
  c.relacl, c.relrowsecurity, c.relforcerowsecurity
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname IN ('user', 'address', 'brand', 'category', 'product', 'product_category', 'product_image', 'product_option', 'product_option_value', 'product_variant', 'variant_option_value', 'inventory_item', 'inventory_reservation', 'inventory_movement', 'cart', 'cart_item', 'checkout_attempt', 'order', 'order_item', 'order_address', 'payment', 'payment_event', '_prisma_migrations') ORDER BY c.relname;
SELECT c.relname AS object_name, a.attname, a.attacl
  FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname IN ('user', 'address', 'brand', 'category', 'product', 'product_category', 'product_image', 'product_option', 'product_option_value', 'product_variant', 'variant_option_value', 'inventory_item', 'inventory_reservation', 'inventory_movement', 'cart', 'cart_item', 'checkout_attempt', 'order', 'order_item', 'order_address', 'payment', 'payment_event', '_prisma_migrations')
    AND a.attnum > 0 AND NOT a.attisdropped ORDER BY c.relname, a.attnum;
SELECT c.relname AS object_name, p.polname, p.polcmd, p.polpermissive,
  ARRAY(SELECT CASE WHEN role_oid = 0 THEN 'PUBLIC' ELSE pg_catalog.pg_get_userbyid(role_oid)::text END
    FROM unnest(p.polroles) role_oid) AS policy_roles,
  pg_catalog.pg_get_expr(p.polqual, p.polrelid) AS using_expression,
  pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) AS check_expression
  FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname IN ('user', 'address', 'brand', 'category', 'product', 'product_category', 'product_image', 'product_option', 'product_option_value', 'product_variant', 'variant_option_value', 'inventory_item', 'inventory_reservation', 'inventory_movement', 'cart', 'cart_item', 'checkout_attempt', 'order', 'order_item', 'order_address', 'payment', 'payment_event', '_prisma_migrations') ORDER BY c.relname, p.polname;
SELECT r.rolname AS creator, COALESCE(n.nspname::text, 'GLOBAL') AS schema,
  d.defaclobjtype, d.defaclacl FROM pg_catalog.pg_default_acl d
  JOIN pg_catalog.pg_roles r ON r.oid = d.defaclrole
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = d.defaclnamespace
  WHERE r.rolname = 'postgres' AND (d.defaclnamespace = 0 OR n.nspname = 'public');
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolbypassrls
  FROM pg_catalog.pg_roles WHERE rolname IN ('postgres','sellio_runtime','anon','authenticated','service_role','authenticator');
SELECT member.rolname AS member, parent.rolname AS granted_role, m.admin_option, m.inherit_option, m.set_option
  FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles member ON member.oid = m.member
  JOIN pg_catalog.pg_roles parent ON parent.oid = m.roleid
  WHERE member.rolname IN ('postgres','sellio_runtime','anon','authenticated','service_role','authenticator')
    OR parent.rolname = 'sellio_runtime';
SELECT nspname, pg_catalog.pg_get_userbyid(nspowner) AS owner, nspacl
  FROM pg_catalog.pg_namespace WHERE nspname = 'public';
SELECT t.typname, pg_catalog.pg_get_userbyid(t.typowner) AS owner, t.typacl
  FROM pg_catalog.pg_type t JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public' AND t.typtype = 'e' AND t.typname IN
    ('user_role','product_status','category_status','variant_status','cart_status',
     'checkout_attempt_status','reservation_status','inventory_movement_reason',
     'order_status','payment_status','payment_provider','payment_event_status','reconciliation_status')
  ORDER BY t.typname;
SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner, datacl
  FROM pg_catalog.pg_database WHERE datname = current_database();
SELECT migration_name, checksum, finished_at, rolled_back_at, applied_steps_count
  FROM public._prisma_migrations ORDER BY started_at;
ROLLBACK;
