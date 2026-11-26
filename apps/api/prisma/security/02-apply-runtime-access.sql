-- PREPARED ONLY: no execution until separate B.2 approval, snapshots and isolated tests.
-- Explicit object scope: 22 application tables plus Prisma history. No wildcard object revokes.
BEGIN;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

DO $preflight$
DECLARE
  runtime_oid oid;
  target text;
BEGIN
  IF current_user <> 'postgres' OR current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'Expected controlled owner connection; abort';
  END IF;
  SELECT oid INTO runtime_oid FROM pg_catalog.pg_roles
    WHERE rolname = 'sellio_runtime' AND NOT rolcanlogin AND NOT rolinherit
      AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
      AND NOT rolreplication AND NOT rolbypassrls;
  IF runtime_oid IS NULL THEN
    RAISE EXCEPTION 'Expected fresh, safe NOLOGIN runtime role';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_shdepend WHERE refobjid = runtime_oid AND deptype = 'o')
     OR pg_catalog.has_database_privilege('sellio_runtime', current_database(), 'CREATE')
     OR pg_catalog.has_schema_privilege('sellio_runtime', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'Unexpected runtime ownership or persistent DDL privileges';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members WHERE member = runtime_oid)
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members m
       JOIN pg_catalog.pg_roles r ON r.oid = m.member
       WHERE m.roleid = runtime_oid AND r.rolname IN ('anon','authenticated','service_role','authenticator')) THEN
    RAISE EXCEPTION 'Unexpected runtime memberships';
  END IF;
  IF (SELECT count(*) FROM public._prisma_migrations) <> 1
     OR NOT EXISTS (SELECT 1 FROM public._prisma_migrations
       WHERE migration_name = '20261120000000_initial'
         AND checksum = '00e9084376d3d894acd2575dcc5999db2286b206b5eafd297a49cae35a5515b6'
         AND finished_at IS NOT NULL AND rolled_back_at IS NULL) THEN
    RAISE EXCEPTION 'Unexpected migration baseline';
  END IF;
  FOREACH target IN ARRAY ARRAY['user', 'address', 'brand', 'category', 'product', 'product_category', 'product_image', 'product_option', 'product_option_value', 'product_variant', 'variant_option_value', 'inventory_item', 'inventory_reservation', 'inventory_movement', 'cart', 'cart_item', 'checkout_attempt', 'order', 'order_item', 'order_address', 'payment', 'payment_event', '_prisma_migrations'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = target AND c.relkind = 'r'
        AND pg_catalog.pg_get_userbyid(c.relowner) = 'postgres') THEN
      RAISE EXCEPTION 'Missing or unexpectedly owned target: %', target;
    END IF;
    IF target <> '_prisma_migrations' AND EXISTS (
      SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = target
        AND (c.relrowsecurity OR c.relforcerowsecurity OR EXISTS (
          SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid = c.oid))) THEN
      RAISE EXCEPTION 'Existing RLS/policies need review: %', target;
    END IF;
  END LOOP;
  FOREACH target IN ARRAY ARRAY['user_role', 'product_status', 'category_status', 'variant_status', 'cart_status', 'checkout_attempt_status', 'reservation_status', 'inventory_movement_reason', 'order_status', 'payment_status', 'payment_provider', 'payment_event_status', 'reconciliation_status'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type t
      JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public' AND t.typname = target AND t.typtype = 'e'
        AND pg_catalog.pg_get_userbyid(t.typowner) = 'postgres') THEN
      RAISE EXCEPTION 'Missing or unexpectedly owned enum: %', target;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_enum e JOIN pg_catalog.pg_type t ON t.oid = e.enumtypid
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'user_role' AND e.enumlabel = 'CUSTOMER') THEN
    RAISE EXCEPTION 'Missing CUSTOMER enum contract';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_default_acl d
    JOIN pg_catalog.pg_roles owner_role ON owner_role.oid = d.defaclrole
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = d.defaclnamespace
    CROSS JOIN LATERAL pg_catalog.aclexplode(d.defaclacl) a
    CROSS JOIN pg_catalog.pg_roles recipient
    WHERE owner_role.rolname = 'postgres' AND d.defaclobjtype IN ('r','S')
      AND d.defaclnamespace = 0
      AND recipient.rolname IN ('sellio_runtime','anon','authenticated','service_role','authenticator')
      AND CASE WHEN a.grantee = 0 THEN true
        ELSE pg_catalog.pg_has_role(recipient.oid, a.grantee, 'USAGE') END
  ) THEN
    RAISE EXCEPTION 'Global future-object grants need separate review; schema-local revokes cannot cancel them';
  END IF;
END;
$preflight$;

GRANT CONNECT ON DATABASE postgres TO sellio_runtime;
GRANT USAGE ON SCHEMA public TO sellio_runtime;
REVOKE CREATE ON SCHEMA public FROM sellio_runtime;

REVOKE ALL PRIVILEGES ON TABLE public."user" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."address" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."brand" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."category" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product_category" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product_image" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product_option" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product_option_value" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."product_variant" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."variant_option_value" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."inventory_item" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."inventory_reservation" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."inventory_movement" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."cart" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."cart_item" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."checkout_attempt" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."order" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."order_item" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."order_address" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."payment" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."payment_event" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
REVOKE ALL PRIVILEGES ON TABLE public."_prisma_migrations" FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;

-- These defaults affect future postgres-created objects in public, not existing unrelated objects.
-- PostgreSQL cannot scope default privileges to a table-name allowlist.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role, authenticator, sellio_runtime;
-- Global PUBLIC EXECUTE and database PUBLIC TEMPORARY are deliberately unchanged.
-- Future application functions must revoke execution explicitly in their creation transaction.

GRANT SELECT, INSERT ON TABLE
  public."user",
  public."address",
  public."brand",
  public."category",
  public."product",
  public."product_category",
  public."product_image",
  public."product_option",
  public."product_option_value",
  public."product_variant",
  public."variant_option_value",
  public."inventory_item",
  public."inventory_reservation",
  public."inventory_movement",
  public."cart",
  public."cart_item",
  public."checkout_attempt",
  public."order",
  public."order_item",
  public."order_address",
  public."payment",
  public."payment_event"
TO sellio_runtime;

GRANT UPDATE ("email", "first_name", "last_name", "updated_at") ON TABLE public."user" TO sellio_runtime;
GRANT UPDATE ("recipient_name", "line1", "line2", "city", "region", "postal_code", "country_code", "phone", "is_default", "updated_at") ON TABLE public."address" TO sellio_runtime;
GRANT UPDATE ("name", "slug", "updated_at") ON TABLE public."brand" TO sellio_runtime;
GRANT UPDATE ("name", "slug", "parent_id", "status", "updated_at") ON TABLE public."category" TO sellio_runtime;
GRANT UPDATE ("name", "slug", "description", "status", "brand_id", "updated_at") ON TABLE public."product" TO sellio_runtime;
GRANT UPDATE ("storage_path", "alt_text", "position", "is_primary", "updated_at") ON TABLE public."product_image" TO sellio_runtime;
GRANT UPDATE ("name", "position", "updated_at") ON TABLE public."product_option" TO sellio_runtime;
GRANT UPDATE ("value", "position", "updated_at") ON TABLE public."product_option_value" TO sellio_runtime;
GRANT UPDATE ("sku", "price", "compare_at_price", "status", "is_default", "option_signature", "updated_at") ON TABLE public."product_variant" TO sellio_runtime;
GRANT UPDATE ("quantity_on_hand", "quantity_reserved", "updated_at") ON TABLE public."inventory_item" TO sellio_runtime;
GRANT UPDATE ("status", "updated_at") ON TABLE public."inventory_reservation" TO sellio_runtime;
GRANT UPDATE ("user_id", "guest_token_hash", "status", "revision", "updated_at") ON TABLE public."cart" TO sellio_runtime;
GRANT UPDATE ("quantity", "updated_at") ON TABLE public."cart_item" TO sellio_runtime;
GRANT UPDATE ("status", "order_id", "processing_token", "processing_lease_expires_at", "retry_count", "next_retry_at", "retention_expires_at", "last_error_code", "updated_at") ON TABLE public."checkout_attempt" TO sellio_runtime;
GRANT UPDATE ("status", "accepted_payment_id", "reconciliation_status", "reconciliation_reason", "reconciliation_detected_at", "reconciliation_resolved_at", "reconciliation_resolved_by_user_id", "reconciliation_resolution_note", "paid_at", "updated_at") ON TABLE public."order" TO sellio_runtime;
GRANT UPDATE ("provider_payment_id", "provider_checkout_session_id", "status", "reconciliation_status", "reconciliation_reason", "reconciliation_detected_at", "reconciliation_resolved_at", "reconciliation_resolved_by_user_id", "reconciliation_resolution_note", "updated_at") ON TABLE public."payment" TO sellio_runtime;
GRANT UPDATE ("payment_id", "processing_status", "processed_at", "error_code") ON TABLE public."payment_event" TO sellio_runtime;

GRANT DELETE ON TABLE public."address" TO sellio_runtime;
GRANT DELETE ON TABLE public."product_category" TO sellio_runtime;
GRANT DELETE ON TABLE public."product_image" TO sellio_runtime;
GRANT DELETE ON TABLE public."variant_option_value" TO sellio_runtime;
GRANT DELETE ON TABLE public."cart_item" TO sellio_runtime;

-- RLS is backend-wide by command; customer authorization remains in NestJS.

ALTER TABLE public."user" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."user" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."user" FOR INSERT TO sellio_runtime WITH CHECK (role = 'CUSTOMER'::public.user_role);
CREATE POLICY sellio_runtime_update ON public."user" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."address" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."address" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."address" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."address" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);
CREATE POLICY sellio_runtime_delete ON public."address" FOR DELETE TO sellio_runtime USING (true);

ALTER TABLE public."brand" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."brand" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."brand" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."brand" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."category" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."category" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."category" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."category" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."product" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."product" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."product_category" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product_category" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product_category" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_delete ON public."product_category" FOR DELETE TO sellio_runtime USING (true);

ALTER TABLE public."product_image" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product_image" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product_image" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."product_image" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);
CREATE POLICY sellio_runtime_delete ON public."product_image" FOR DELETE TO sellio_runtime USING (true);

ALTER TABLE public."product_option" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product_option" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product_option" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."product_option" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."product_option_value" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product_option_value" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product_option_value" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."product_option_value" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."product_variant" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."product_variant" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."product_variant" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."product_variant" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."variant_option_value" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."variant_option_value" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."variant_option_value" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_delete ON public."variant_option_value" FOR DELETE TO sellio_runtime USING (true);

ALTER TABLE public."inventory_item" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."inventory_item" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."inventory_item" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."inventory_item" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."inventory_reservation" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."inventory_reservation" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."inventory_reservation" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."inventory_reservation" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."inventory_movement" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."inventory_movement" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."inventory_movement" FOR INSERT TO sellio_runtime WITH CHECK (true);

ALTER TABLE public."cart" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."cart" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."cart" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."cart" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."cart_item" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."cart_item" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."cart_item" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."cart_item" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);
CREATE POLICY sellio_runtime_delete ON public."cart_item" FOR DELETE TO sellio_runtime USING (true);

ALTER TABLE public."checkout_attempt" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."checkout_attempt" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."checkout_attempt" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."checkout_attempt" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."order" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."order" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."order" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."order" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."order_item" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."order_item" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."order_item" FOR INSERT TO sellio_runtime WITH CHECK (true);

ALTER TABLE public."order_address" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."order_address" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."order_address" FOR INSERT TO sellio_runtime WITH CHECK (true);

ALTER TABLE public."payment" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."payment" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."payment" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."payment" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

ALTER TABLE public."payment_event" ENABLE ROW LEVEL SECURITY;
CREATE POLICY sellio_runtime_select ON public."payment_event" FOR SELECT TO sellio_runtime USING (true);
CREATE POLICY sellio_runtime_insert ON public."payment_event" FOR INSERT TO sellio_runtime WITH CHECK (true);
CREATE POLICY sellio_runtime_update ON public."payment_event" FOR UPDATE TO sellio_runtime USING (true) WITH CHECK (true);

-- Role stays NOLOGIN. Do not provision credentials or activate it in this script.
COMMIT;
