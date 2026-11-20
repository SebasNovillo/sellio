# Sellio — Prisma Foundation, Part A

**Date:** 2026-11-20  
**Status:** Prisma schema/client/infrastructure implemented; no migration generated or applied and no database connection performed. The owner authorized Part A and consistent documented contracts; approval is still required before the first migration is applied.

## 1. Scope and pinned dependencies

The source is [schema.prisma](../../apps/api/prisma/schema.prisma), derived from the [implementation specification](DATABASE_IMPLEMENTATION_SPEC.md), [database design](Sellio_DATABASE_DESIGN.md), [ERD](ERD.md), ADR-006 and ADR-010. No product, checkout, authentication or Stripe service, seed data or migration is included.

- prisma, @prisma/client and @prisma/adapter-pg: **7.10.1** each, pinned exactly in apps/api.
- dotenv: **18.0.10**, pinned exactly for Prisma CLI environment loading.
- The pg driver is an adapter dependency, locked transitively; no unused direct driver dependency is added.
- Existing Node 22.22.3, TypeScript 5.9.3, NestJS 12 and ESM are retained. Prisma's current latest tag points to an 8.0 release candidate, so this foundation deliberately uses stable 7.10.1.
- PostgreSQL datasource; provision a supported stable server and confirm its version before migration. UUID defaults use native gen_random_uuid(), requiring PostgreSQL 13+; use a currently supported release, not an EOL baseline. No pgcrypto extension is needed for that native function.

The prisma-client generator emits ESM TypeScript under apps/api/src/generated/prisma with .js import specifiers for compiled NodeNext output. Generated source, dist, test compilation and caches are ignored. Build/typecheck generate the client; Turbo restores generated source with cached API task outputs. No postinstall schema mutation or migration runs.

## 2. Model and enum inventory

| Domain | Models |
| --- | --- |
| Identity | User, Address |
| Catalog | Brand, Category, Product, ProductCategory, ProductImage |
| Options | ProductOption, ProductOptionValue, ProductVariant, VariantOptionValue |
| Inventory | InventoryItem, InventoryReservation, InventoryMovement |
| Shopping | Cart, CartItem |
| Checkout | CheckoutAttempt |
| Orders | Order, OrderItem, OrderAddress |
| Payments | Payment, PaymentEvent |

Exactly **22 models** and **13 enums**: UserRole, ProductStatus, CategoryStatus, VariantStatus, CartStatus, CheckoutAttemptStatus, ReservationStatus, InventoryMovementReason, OrderStatus, PaymentStatus, PaymentProvider, PaymentEventStatus, ReconciliationStatus. Values match the implementation-specification enum table. Status inputs are explicit rather than introducing new lifecycle defaults. Reconciliation defaults to NONE and user roles to CUSTOMER.

UUID primary keys apply except ProductCategory(product_id, category_id) and VariantOptionValue(variant_id, option_value_id). Tables, enum types and compound constraints/indexes use snake_case mappings. Timestamps use timestamptz(6); created/received timestamps default to now, mutable records use Prisma-managed updated_at, and historical lines/addresses/movements are not given mutable update timestamps.

## 3. Implemented constraints and relationship choices

- Required user ownership for Order and CheckoutAttempt; optional guest Cart owner. No cross-database Supabase FK.
- Required checkout/order/inventory links on InventoryReservation, unique attempt/inventory line; optional reservation/order/actor links on InventoryMovement.
- CheckoutAttempt scoped user/key uniqueness, bounded key, 64-character fingerprint, snapshot/version/revision, order uniqueness and retry/lease/fencing fields.
- Unique Order.source_cart_id prevents another order from the same cart, including after attempt cleanup.
- Order.accepted_payment_id is optional/unique; the Prisma composite FK (accepted_payment_id, id) -> Payment(id, order_id) enforces same-order membership. A supporting compound unique key on each side makes the one-to-one relation explicit to Prisma. The redundant accepted-payment/id unique index is intentional for schema relation validation.
- Multiple Payment rows can remain SUCCEEDED. No unique status-per-order constraint or implicit refund status is introduced. Reconciliation state, reason, detection/resolution timestamps, resolver FK and resolution note are persisted on both Order and Payment.
- Nullable PaymentEvent.provider_object_id is the minimal safe relinking reference. No raw event/card payload storage is added. Receipt processing retry still requires a later service.
- Unique auth ID, slugs, SKU, option names/values, option signatures, cart lines, variant inventory, order number/address and provider-scoped payment/session/event IDs are in Prisma. PostgreSQL ordinary nullable unique keys permit multiple NULL provider references; no partial SQL is needed to achieve that behavior.
- Referential actions follow specification section 8: RESTRICT for financial/history/stock parents, SET NULL only for documented optional references, CASCADE only for owned saved/configuration rows. All FK updates use RESTRICT.
- Optional composite checkout/cart/user ownership FKs were **not adopted**: the documentation permits locked service checks instead. Required same-owner/same-source consistency, reservation-to-attempt/order consistency and option ownership remain service invariants. Cart.user_id retains SET NULL accordingly. No new business rule was inferred from the optional FK alternative.
- Baseline read/recovery/FK indexes are in Prisma; indexes already covered by a unique left prefix are not duplicated unnecessarily. Stable Prisma 7 supports the compound accepted-payment FK directly.

## 4. Explicit provisional nullability and remaining ambiguities

The owner authorized implementing consistent proposed contracts, not inventing absent business rules. These details are visible for migration review:

- Decimal(12,2), explicit Char(3) currency and a 1024-character option-signature field implement the documented concrete proposals. Future SQL adds the documented ASCII byte bound; service encoding remains versioned UUID-pair normalization.
- Order totals and purchased line base amounts are required. Additional OrderItem.tax_total/discount_total and Order.tax_details_snapshot/shipping_method_snapshot are **nullable**, representing unspecified provider detail, not zero tax/discount or a completed quote. Confirm requiredness and tax-inclusive/discount allocation semantics before the first migration; there are no invented financial defaults.
- Address line2/phone/region and matching historical address fields are nullable; geography-specific region requirements remain service validation. Product.description is nullable during draft assembly. Name/SKU/address snapshots and core address fields are required. These nullability details must be included in the owner's schema review.
- Brand archival representation, non-option filter metadata, variant media and guest-token uniqueness/owner exclusivity are not specified. No extra fields/models or geographic restrictions are silently added. Decide whether the baseline needs more storage before generating the final migration; no 23rd entity is authorized.
- Payment provider-object retry semantics, accepted-settlement success/amount/currency guards, tax quote finalization and privacy/audit enforcement remain unimplemented service/operational requirements.

## 5. CLI environment and NestJS integration

[prisma.config.ts](../../apps/api/prisma.config.ts) explicitly loads shell > apps/api/.env.local > apps/api/.env using paths relative to the config file. Missing URLs are permitted for validation/generation. CLI migration URL prefers DATABASE_MIGRATION_URL when supplied, otherwise DATABASE_URL; an actual migration will require a valid URL. Neither URL is placed in generated source.

The API's DatabaseModule exports PrismaService. Runtime uses ConfigService.DATABASE_URL and PrismaPg; it never uses a privileged migration URL. A configured runtime URL is required to instantiate the service. URL validation rejects empty/non-PostgreSQL inputs without logging credentials. Construction is lazy: no onModuleInit connection, readiness query, schema synchronization or startup migration. Shutdown disconnects the client. Existing health remains process-only.

Root commands (with pinned pnpm active):

```sh
pnpm --filter @sellio/api db:validate
pnpm --filter @sellio/api db:generate
pnpm --filter @sellio/api db:format
pnpm --filter @sellio/api test:database
pnpm lint
pnpm typecheck
pnpm build
```

Formatting writes only the schema. Validation/generation require no database. Tests compile TypeScript and run Node's built-in runner: URL validation, generated inventory and lazy constructor/shutdown with TCP calls prohibited. They do not prove live PostgreSQL constraint enforcement. CI includes these offline checks; no PostgreSQL CI service or migration execution is introduced in Part A.

## 6. SQL required in the future initial migration

**Documentation only. None of these statements has been executed.** Stable schema constraints are implemented in Prisma. CHECK constraints are not represented by this Prisma 7 schema. Partial indexes require the partialIndexes preview feature in 7.10.1; preview features are deliberately disabled. Therefore a future reviewed migration must append the following SQL after generated tables/types/keys. Do not deploy the schema alone and assume these protections exist.

Use the actual mapped names below. These statements are for a fresh baseline, not a rerunnable schema-patching script; do not mask drift with IF NOT EXISTS.

### Partial unique indexes

```sql
CREATE UNIQUE INDEX address_one_default_per_user_key
  ON address (user_id) WHERE is_default;
CREATE UNIQUE INDEX product_image_one_primary_key
  ON product_image (product_id) WHERE is_primary;
CREATE UNIQUE INDEX product_variant_one_default_key
  ON product_variant (product_id) WHERE is_default;
CREATE UNIQUE INDEX cart_one_active_per_user_key
  ON cart (user_id) WHERE status = 'ACTIVE' AND user_id IS NOT NULL;
CREATE UNIQUE INDEX checkout_attempt_one_live_per_cart_key
  ON checkout_attempt (cart_id)
  WHERE status IN ('RECEIVED', 'PROCESSING', 'AWAITING_PAYMENT');
CREATE UNIQUE INDEX inventory_movement_one_sale_per_reservation_key
  ON inventory_movement (reservation_id)
  WHERE reason = 'SALE' AND reservation_id IS NOT NULL;
```

The single-active-cart index implements the documented proposal and needs explicit approval in the migration review. Guest-token hash uniqueness remains conditional on the unresolved guest-identity design; do not add an ownership XOR CHECK or token format assumption without that decision.

### Inventory, quantity and idempotency checks

```sql
ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_balance_check
  CHECK (quantity_on_hand >= 0 AND quantity_reserved >= 0
    AND quantity_reserved <= quantity_on_hand);
ALTER TABLE inventory_reservation ADD CONSTRAINT inventory_reservation_quantity_check
  CHECK (quantity > 0);
ALTER TABLE cart_item ADD CONSTRAINT cart_item_quantity_check CHECK (quantity > 0);
ALTER TABLE order_item ADD CONSTRAINT order_item_quantity_check CHECK (quantity > 0);
ALTER TABLE cart ADD CONSTRAINT cart_revision_check CHECK (revision >= 0);
ALTER TABLE checkout_attempt ADD CONSTRAINT checkout_attempt_input_check CHECK (
  cart_revision >= 0 AND retry_count >= 0 AND fingerprint_version > 0
  AND char_length(idempotency_key) > 0
  AND request_fingerprint::text ~ '^[0-9a-f]{64}$'
);
ALTER TABLE product_variant ADD CONSTRAINT product_variant_signature_check CHECK (
  char_length(option_signature) > 0 AND octet_length(option_signature) <= 1024
  AND octet_length(option_signature) = char_length(option_signature)
);
ALTER TABLE category ADD CONSTRAINT category_not_own_parent_check CHECK (parent_id <> id);
ALTER TABLE inventory_movement ADD CONSTRAINT inventory_movement_sale_reference_check
  CHECK (reason <> 'SALE' OR reservation_id IS NOT NULL);
```

The signature byte/character equality assumes the future database uses UTF8 encoding, to be verified during provisioning. Exact canonical ordering/signature equality, lease ownership, cart conversion state, reservation sums and matching movement quantities are cross-record/service rules, not claimed CHECK guarantees.

### Monetary checks

Finite comparisons intentionally reject PostgreSQL numeric NaN as well as negative amounts. Required fields already use NOT NULL; nullable extra line allocations stay unknown until supplied. Confirm the documented line/subtotal interpretation and allocation rules during migration review.

```sql
ALTER TABLE product_variant ADD CONSTRAINT product_variant_money_check CHECK (
  currency = 'USD' AND price >= 0 AND price < 'Infinity'::numeric
  AND (compare_at_price IS NULL OR (compare_at_price >= 0 AND compare_at_price < 'Infinity'::numeric))
);
ALTER TABLE "order" ADD CONSTRAINT order_money_check CHECK (
  currency = 'USD'
  AND subtotal >= 0 AND subtotal < 'Infinity'::numeric
  AND shipping_total >= 0 AND shipping_total < 'Infinity'::numeric
  AND tax_total >= 0 AND tax_total < 'Infinity'::numeric
  AND discount_total >= 0 AND discount_total < 'Infinity'::numeric
  AND grand_total >= 0 AND grand_total < 'Infinity'::numeric
  AND grand_total = subtotal + shipping_total + tax_total - discount_total
);
ALTER TABLE order_item ADD CONSTRAINT order_item_money_check CHECK (
  currency = 'USD'
  AND unit_price >= 0 AND unit_price < 'Infinity'::numeric
  AND line_total >= 0 AND line_total < 'Infinity'::numeric
  AND (tax_total IS NULL OR (tax_total >= 0 AND tax_total < 'Infinity'::numeric))
  AND (discount_total IS NULL OR (discount_total >= 0 AND discount_total < 'Infinity'::numeric))
  AND line_total = quantity * unit_price
);
ALTER TABLE payment ADD CONSTRAINT payment_money_check CHECK (
  currency = 'USD' AND amount >= 0 AND amount < 'Infinity'::numeric
);
```

No CHECK sums order lines, guarantees a published default/balance exists, enforces option completeness/category acyclicity, confirms provider success or freezes historical rows. No unique index limits SUCCEEDED Payment rows. Those invariants need later transactions, permissions and, if approved, triggers. Applying the SQL still does not implement checkout or fulfill an order safely by itself.

## 7. First migration strategy and remaining gates

1. Review schema plus this SQL as one unit. Resolve provisional financial/address nullability, required filter/media/brand storage, guest/cart conditional indexes and enforcement/audit requirements. Confirm provider choices do not require different immutable snapshot storage. Runtime/CLI environment selection is not authorization to migrate.
2. Provision an explicitly approved isolated PostgreSQL database/version with UTF8. Supply reviewed migration/runtime credentials separately. Confirm native UUID defaults and decimal/check behavior on that server.
3. In a separately authorized task, generate a create-only baseline migration covering 22 tables and 13 enum types, then append section 6 SQL. Order creation of the cyclic Order/Payment relations through generated ALTER TABLE FKs. Never hand-edit generated client files.
4. Review every FK/action/index/check, especially accepted-payment same-order membership, source-cart uniqueness and no restriction on multiple actual settlements. Review SQL edits so future Prisma diff/migration operations do not drop custom features.
5. Only with explicit approval, apply to the isolated database and run negative constraint, FK deletion, concurrency, transaction rollback and idempotency tests. No production connection/reset or seeds are part of Part A. A separately reviewed deployment uses migration history, never db push.
6. Future migration/seed Turbo tasks must be non-cacheable and must not run as application startup hooks or ordinary build steps. Add database-backed CI only with the next authorized migration task.

Before live use, resolve tax/shipping calculation/finalization, 30-minute provider coordination, cancellation/late-payment reconciliation, data retention/anonymization, same-owner/source service checks, append-only enforcement and immutable financial correction policy. Their durations/algorithms can follow later only when approved schema storage is sufficient.

## 8. Technical references

- [Prisma 7 generators](https://www.prisma.io/docs/orm/v7/prisma-schema/overview/generators)
- [Prisma 7 config](https://www.prisma.io/docs/orm/v7/reference/prisma-config-reference)
- [Prisma 7 partial indexes](https://www.prisma.io/docs/orm/v7/prisma-schema/data-model/indexes#configuring-partial-indexes-with-where)
- [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
