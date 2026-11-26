-- PREPARED ONLY. Run read-only after approved B.2 application; never activates a login.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '15s';

DO $verify$
DECLARE
  runtime_oid oid;
  target record;
  role_name text;
  privilege_name text;
  attribute record;
  policy record;
  table_oid oid;
  expected_count integer;
  expression text;
BEGIN
  SELECT oid INTO runtime_oid FROM pg_catalog.pg_roles
    WHERE rolname = 'sellio_runtime' AND NOT rolinherit AND NOT rolsuper
      AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls;
  IF runtime_oid IS NULL THEN RAISE EXCEPTION 'Unsafe or missing runtime role'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members WHERE member = runtime_oid)
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_shdepend WHERE refobjid = runtime_oid AND deptype = 'o') THEN
    RAISE EXCEPTION 'Runtime must have no memberships or ownership';
  END IF;
  IF pg_catalog.has_database_privilege('sellio_runtime', current_database(), 'CREATE')
     OR pg_catalog.has_schema_privilege('sellio_runtime', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'Unexpected runtime persistent DDL privilege';
  END IF;
  IF NOT pg_catalog.has_database_privilege('sellio_runtime', current_database(), 'CONNECT')
     OR NOT pg_catalog.has_schema_privilege('sellio_runtime', 'public', 'USAGE') THEN
    RAISE EXCEPTION 'Missing runtime connection/schema access';
  END IF;
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role','authenticator'] LOOP
    IF pg_catalog.pg_has_role(role_name, 'sellio_runtime', 'MEMBER') THEN
      RAISE EXCEPTION 'API role can assume/inherit runtime: %', role_name;
    END IF;
  END LOOP;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_default_acl d
    JOIN pg_catalog.pg_roles owner_role ON owner_role.oid = d.defaclrole
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = d.defaclnamespace
    CROSS JOIN LATERAL pg_catalog.aclexplode(d.defaclacl) a
    CROSS JOIN pg_catalog.pg_roles recipient
    WHERE owner_role.rolname = 'postgres' AND d.defaclobjtype IN ('r','S')
      AND (d.defaclnamespace = 0 OR n.nspname = 'public')
      AND recipient.rolname IN ('sellio_runtime','anon','authenticated','service_role','authenticator')
      AND CASE WHEN a.grantee = 0 THEN true
        ELSE pg_catalog.pg_has_role(recipient.oid, a.grantee, 'USAGE') END
  ) THEN
    RAISE EXCEPTION 'Unexpected future table/sequence privileges';
  END IF;
  FOR target IN SELECT * FROM (VALUES
    ('user', ARRAY['email', 'first_name', 'last_name', 'updated_at']::text[], false, 'role = ''CUSTOMER''::public.user_role'),
    ('address', ARRAY['recipient_name', 'line1', 'line2', 'city', 'region', 'postal_code', 'country_code', 'phone', 'is_default', 'updated_at']::text[], true, 'true'),
    ('brand', ARRAY['name', 'slug', 'updated_at']::text[], false, 'true'),
    ('category', ARRAY['name', 'slug', 'parent_id', 'status', 'updated_at']::text[], false, 'true'),
    ('product', ARRAY['name', 'slug', 'description', 'status', 'brand_id', 'updated_at']::text[], false, 'true'),
    ('product_category', ARRAY[]::text[], true, 'true'),
    ('product_image', ARRAY['storage_path', 'alt_text', 'position', 'is_primary', 'updated_at']::text[], true, 'true'),
    ('product_option', ARRAY['name', 'position', 'updated_at']::text[], false, 'true'),
    ('product_option_value', ARRAY['value', 'position', 'updated_at']::text[], false, 'true'),
    ('product_variant', ARRAY['sku', 'price', 'compare_at_price', 'status', 'is_default', 'option_signature', 'updated_at']::text[], false, 'true'),
    ('variant_option_value', ARRAY[]::text[], true, 'true'),
    ('inventory_item', ARRAY['quantity_on_hand', 'quantity_reserved', 'updated_at']::text[], false, 'true'),
    ('inventory_reservation', ARRAY['status', 'updated_at']::text[], false, 'true'),
    ('inventory_movement', ARRAY[]::text[], false, 'true'),
    ('cart', ARRAY['user_id', 'guest_token_hash', 'status', 'revision', 'updated_at']::text[], false, 'true'),
    ('cart_item', ARRAY['quantity', 'updated_at']::text[], true, 'true'),
    ('checkout_attempt', ARRAY['status', 'order_id', 'processing_token', 'processing_lease_expires_at', 'retry_count', 'next_retry_at', 'retention_expires_at', 'last_error_code', 'updated_at']::text[], false, 'true'),
    ('order', ARRAY['status', 'accepted_payment_id', 'reconciliation_status', 'reconciliation_reason', 'reconciliation_detected_at', 'reconciliation_resolved_at', 'reconciliation_resolved_by_user_id', 'reconciliation_resolution_note', 'paid_at', 'updated_at']::text[], false, 'true'),
    ('order_item', ARRAY[]::text[], false, 'true'),
    ('order_address', ARRAY[]::text[], false, 'true'),
    ('payment', ARRAY['provider_payment_id', 'provider_checkout_session_id', 'status', 'reconciliation_status', 'reconciliation_reason', 'reconciliation_detected_at', 'reconciliation_resolved_at', 'reconciliation_resolved_by_user_id', 'reconciliation_resolution_note', 'updated_at']::text[], false, 'true'),
    ('payment_event', ARRAY['payment_id', 'processing_status', 'processed_at', 'error_code']::text[], false, 'true'),
    ('_prisma_migrations', ARRAY[]::text[], false, 'false')
  ) AS v(table_name, update_columns, can_delete, insert_check) LOOP
    SELECT c.oid INTO table_oid FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = target.table_name
        AND c.relkind = 'r' AND pg_catalog.pg_get_userbyid(c.relowner) = 'postgres';
    IF table_oid IS NULL THEN RAISE EXCEPTION 'Missing/changed owner: %', target.table_name; END IF;
    IF pg_catalog.has_table_privilege('sellio_runtime', table_oid, 'SELECT') <> (target.table_name <> '_prisma_migrations')
       OR pg_catalog.has_table_privilege('sellio_runtime', table_oid, 'INSERT') <> (target.table_name <> '_prisma_migrations')
       OR pg_catalog.has_table_privilege('sellio_runtime', table_oid, 'DELETE') <> target.can_delete
       OR pg_catalog.has_table_privilege('sellio_runtime', table_oid, 'UPDATE') THEN
      RAISE EXCEPTION 'Unexpected runtime table grants: %', target.table_name;
    END IF;
    FOREACH privilege_name IN ARRAY ARRAY['TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] LOOP
      IF pg_catalog.has_table_privilege('sellio_runtime', table_oid, privilege_name) THEN
        RAISE EXCEPTION 'Unexpected runtime privilege % on %', privilege_name, target.table_name;
      END IF;
    END LOOP;
    FOR attribute IN SELECT attname, attnum FROM pg_catalog.pg_attribute
      WHERE attrelid = table_oid AND attnum > 0 AND NOT attisdropped LOOP
      IF pg_catalog.has_column_privilege('sellio_runtime', table_oid, attribute.attnum, 'UPDATE')
         <> (attribute.attname = ANY(target.update_columns)) THEN
        RAISE EXCEPTION 'Unexpected UPDATE grant: %.%', target.table_name, attribute.attname;
      END IF;
    END LOOP;
    FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role','authenticator'] LOOP
      FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] LOOP
        IF pg_catalog.has_table_privilege(role_name, table_oid, privilege_name) THEN
          RAISE EXCEPTION 'Unexpected API privilege: % % %', role_name, target.table_name, privilege_name;
        END IF;
      END LOOP;
      FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','REFERENCES'] LOOP
        IF pg_catalog.has_any_column_privilege(role_name, table_oid, privilege_name) THEN
          RAISE EXCEPTION 'Unexpected API column privilege: % % %', role_name, target.table_name, privilege_name;
        END IF;
      END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c
      CROSS JOIN LATERAL pg_catalog.aclexplode(c.relacl) a WHERE c.oid = table_oid AND a.grantee = 0) THEN
      RAISE EXCEPTION 'PUBLIC table grants remain: %', target.table_name;
    END IF;
    IF target.table_name = '_prisma_migrations' THEN
      IF pg_catalog.has_any_column_privilege('sellio_runtime', table_oid, 'SELECT')
         OR pg_catalog.has_any_column_privilege('sellio_runtime', table_oid, 'INSERT') THEN
        RAISE EXCEPTION 'Runtime column access to migration history';
      END IF;
      CONTINUE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid = table_oid
      AND relrowsecurity AND NOT relforcerowsecurity) THEN
      RAISE EXCEPTION 'Unexpected RLS flags: %', target.table_name;
    END IF;
    expected_count := 2 + CASE WHEN cardinality(target.update_columns) > 0 THEN 1 ELSE 0 END
      + CASE WHEN target.can_delete THEN 1 ELSE 0 END;
    IF (SELECT count(*) FROM pg_catalog.pg_policy WHERE polrelid = table_oid) <> expected_count THEN
      RAISE EXCEPTION 'Unexpected policy count: %', target.table_name;
    END IF;
    FOR policy IN SELECT *, pg_catalog.pg_get_expr(polqual, polrelid) AS using_expression,
      pg_catalog.pg_get_expr(polwithcheck, polrelid) AS check_expression
      FROM pg_catalog.pg_policy WHERE polrelid = table_oid LOOP
      IF policy.polcmd NOT IN ('r','a','w','d')
         OR policy.polroles <> ARRAY[runtime_oid] OR NOT policy.polpermissive
         OR policy.polname <> ('sellio_runtime_' || CASE policy.polcmd
           WHEN 'r' THEN 'select' WHEN 'a' THEN 'insert' WHEN 'w' THEN 'update' WHEN 'd' THEN 'delete' ELSE 'invalid' END) THEN
        RAISE EXCEPTION 'Unexpected policy role/name: %.%', target.table_name, policy.polname;
      END IF;
      IF policy.polcmd IN ('r','w','d') AND policy.using_expression IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Unexpected USING: %.%', target.table_name, policy.polname;
      END IF;
      IF policy.polcmd IN ('r','d') AND policy.check_expression IS NOT NULL THEN
        RAISE EXCEPTION 'Unexpected WITH CHECK: %.%', target.table_name, policy.polname;
      END IF;
      IF policy.polcmd = 'w' AND (cardinality(target.update_columns) = 0 OR policy.check_expression IS DISTINCT FROM 'true') THEN
        RAISE EXCEPTION 'Unexpected update policy: %', target.table_name;
      END IF;
      IF policy.polcmd = 'd' AND NOT target.can_delete THEN
        RAISE EXCEPTION 'Unexpected delete policy: %', target.table_name;
      END IF;
      IF policy.polcmd = 'a' THEN
        expression := replace(replace(regexp_replace(policy.check_expression, '[[:space:]()]', '', 'g'), '::public.user_role', '::user_role'), '"', '');
        IF expression IS DISTINCT FROM replace(regexp_replace(target.insert_check, '[[:space:]()]', '', 'g'), '::public.user_role', '::user_role') THEN
          RAISE EXCEPTION 'Unexpected insert policy: %', target.table_name;
        END IF;
      END IF;
    END LOOP;
  END LOOP;
END;
$verify$;

-- Login activation and deferred inherited TEMPORARY rights must be assessed separately.
SELECT rolname, rolcanlogin, has_database_privilege(oid, current_database(), 'TEMPORARY') AS inherited_temporary
  FROM pg_catalog.pg_roles WHERE rolname = 'sellio_runtime';
ROLLBACK;
