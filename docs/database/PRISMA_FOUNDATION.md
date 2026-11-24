# Sellio — Prisma Foundation, Part A

**Date:** 2026-11-20  
**Status:** Part A and initial migration preparation complete. After separate explicit authorization, the unchanged initial migration was applied and verified in sellio-dev on 2026-11-23; see the [deployment record](initial-migration-verification.md). No further database changes are authorized by this document.

## 1. Scope and pinned dependencies

The source is [schema.prisma](../../apps/api/prisma/schema.prisma), derived from the [implementation specification](DATABASE_IMPLEMENTATION_SPEC.md), [database design](Sellio_DATABASE_DESIGN.md), [ERD](ERD.md), ADR-006 and ADR-010. The initial migration adds the documented SQL below; no product, checkout, authentication or Stripe service or seed data is included.

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
- Optional composite checkout/cart/user ownership FKs were **not adopted**: the documentation permits locked service checks instead. Required same-owner/same-source consistency, reservation-to-attempt/order consistency and option ownership remain service invariants. Cart.user_id now uses RESTRICT: SET NULL could leave an authenticated cart with neither owner nor guest token and violate the approved ownership CHECK. Retain/anonymize an owning user or explicitly remove/reassign permissible carts; never silently turn an owned cart into an anonymous cart without a token.
- Baseline read/recovery/FK indexes are in Prisma; indexes already covered by a unique left prefix are not duplicated unnecessarily. Stable Prisma 7 supports the compound accepted-payment FK directly.

## 4. Approved migration-readiness decisions

The owner approved the four migration-readiness decisions on 2026-11-20:

- Decimal(12,2), explicit Char(3) currency and a 1024-character option-signature field implement the documented concrete proposals. Future SQL adds the documented ASCII byte bound; service encoding remains versioned UUID-pair normalization.
- Unit price, quantity and gross line total are required: line_total = quantity * unit_price, before discounts and taxes. Subtotal is the sum of gross line totals. Order grand_total = subtotal + shipping_total + tax_total - discount_total; line tax/discount allocations are explanatory breakdowns, not amounts added/subtracted a second time. Line allocations remain nullable and mean unavailable, not zero. Existing optional order tax/shipping descriptive JSON is retained; required order-level amounts remain authoritative.
- Order.shipping_total and tax_total remain required Decimal(12,2) and now default to zero, supporting no-charge shipping/zero-tax cases. Defaults do not establish a valid quote; later checkout services must still calculate taxes/shipping and freeze final amounts. Required subtotal, discount_total and grand_total remain explicit; no new monetary field is introduced.
- Saved and historical address line2/phone/region nullability is approved. Country-specific validation stays in services. Product.description remains nullable during draft assembly. Name/SKU/address snapshots and core address fields are required.
- Existing Brand, product images and variant options are retained. Additional brand archival fields, non-option attribute storage and variant media are explicitly deferred from the baseline. No 23rd entity or media integration is introduced.
- At most one ACTIVE cart per authenticated customer; unique non-null guest token hashes; exactly one of user_id/guest_token_hash must be present. Stored token values remain hashes, not raw client secrets. Cart-to-customer claiming updates user_id and clears guest_token_hash in one SQL statement/transaction; separate updates would fail the immediate CHECK. If an active customer cart already exists, merge/choose a destination transactionally before claiming rather than bypass uniqueness. Historical source-cart and checkout ownership checks remain required. No merge algorithm is implemented here.
- Payment provider-object retry semantics, accepted-settlement success/amount/currency guards, tax quote finalization and privacy/audit enforcement remain unimplemented service/operational requirements.

## 5. CLI environment and NestJS integration

[prisma.config.ts](../../apps/api/prisma.config.ts) explicitly loads shell > apps/api/.env.local > apps/api/.env using paths relative to the config file. Missing/blank DIRECT_URL is permitted for offline validation/generation. Database-connected CLI commands use datasource.url = DIRECT_URL exclusively, with no fallback to runtime DATABASE_URL. The former DATABASE_MIGRATION_URL setting is no longer read. Neither URL is placed in generated source. See [Supabase connections](SUPABASE_CONNECTIONS.md) for local setup and the transaction/session pooler split.

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

**Review SQL only. None of these statements has been executed against a database.** Stable schema constraints are implemented in Prisma. CHECK constraints are not represented by this Prisma 7 schema. Partial indexes require the partialIndexes preview feature in 7.10.1; preview features are deliberately disabled. The locally prepared migration appends the following SQL after generated tables/types/keys. Do not deploy the schema alone and assume these protections exist.

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
CREATE UNIQUE INDEX cart_guest_token_hash_key
  ON cart (guest_token_hash) WHERE guest_token_hash IS NOT NULL;
CREATE UNIQUE INDEX checkout_attempt_one_live_per_cart_key
  ON checkout_attempt (cart_id)
  WHERE status IN ('RECEIVED', 'PROCESSING', 'AWAITING_PAYMENT');
CREATE UNIQUE INDEX inventory_movement_one_sale_per_reservation_key
  ON inventory_movement (reservation_id)
  WHERE reason = 'SALE' AND reservation_id IS NOT NULL;
```

The single-active-cart and guest-token indexes are now approved. The ownership CHECK below uses NULL presence only; token format/generation and guest-to-user merge services are not invented by the migration.

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
ALTER TABLE cart ADD CONSTRAINT cart_exactly_one_owner_check
  CHECK ((user_id IS NOT NULL) <> (guest_token_hash IS NOT NULL));
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

Finite comparisons intentionally reject PostgreSQL numeric NaN as well as negative amounts. Required fields already use NOT NULL; nullable extra line allocations stay unknown until supplied. The approved gross-line/subtotal interpretation is used below; allocations must not be counted twice.

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

1. The owner resolved financial/address nullability, gross line accounting, guest/cart constraints and baseline catalog scope. No schema-readiness blocker from those four gates remains. Review the generated schema SQL plus section 6 as one unit. Runtime/CLI environment selection is not authorization to apply a migration.
2. Provision an explicitly approved isolated PostgreSQL database/version with UTF8. Supply reviewed migration/runtime credentials separately. Confirm native UUID defaults and decimal/check behavior on that server.
3. Generate SQL locally with Prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script and prisma.offline.config.ts (no environment loading or real datasource URL; a fixed loopback placeholder supplies engine metadata). This datamodel-to-datamodel operation needs no database or shadow database. Append section 6 SQL; create migration_lock.toml for PostgreSQL. Do not use migrate dev --create-only here, because it can require a database/shadow database. Cyclic Order/Payment FKs are added after table creation.
4. Review every FK/action/index/check, especially accepted-payment same-order membership, source-cart uniqueness and no restriction on multiple actual settlements. Review SQL edits so future Prisma diff/migration operations do not drop custom features.
5. Only with explicit approval, apply to the isolated database and run negative constraint, FK deletion, concurrency, transaction rollback and idempotency tests. No production connection/reset or seeds are part of Part A. A separately reviewed deployment uses migration history, never db push.
6. Future migration/seed Turbo tasks must be non-cacheable and must not run as application startup hooks or ordinary build steps. Add database-backed CI only with the next authorized migration task.

Before live use, resolve tax/shipping calculation/finalization, 30-minute provider coordination, cancellation/late-payment reconciliation, data retention/anonymization, same-owner/source service checks, append-only enforcement and immutable financial correction policy. Their durations/algorithms can follow later only when approved schema storage is sufficient.

## 8. Technical references

- [Prisma 7 generators](https://www.prisma.io/docs/orm/v7/prisma-schema/overview/generators)
- [Prisma 7 config](https://www.prisma.io/docs/orm/v7/reference/prisma-config-reference)
- [Prisma 7 partial indexes](https://www.prisma.io/docs/orm/v7/prisma-schema/data-model/indexes#configuring-partial-indexes-with-where)
- [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)

## 9. Prepared initial migration and offline review

Files: [initial migration](../../apps/api/prisma/migrations/20261120000000_initial/migration.sql) and [provider lock](../../apps/api/prisma/migrations/migration_lock.toml). Reviewed inventory: **22 tables, 13 enum types, 22 primary keys, 35 FKs, 29 unique indexes (including 7 partial), 30 non-unique indexes and 14 CHECK constraints**. FK deletes are 26 RESTRICT, 5 CASCADE for saved/configuration dependents, and 4 SET NULL on historical optional references; all updates RESTRICT. Cart ownership now uses RESTRICT. The full script is wrapped in BEGIN/COMMIT for atomic DDL; it contains no destructive statements.

The generated table/type/key/index portion was produced with installed Prisma 7.10.1 from empty datamodel to the local schema, using [prisma.offline.config.ts](../../apps/api/prisma.offline.config.ts). That config loads no environment files or real credentials. This engine build requires a datasource descriptor even for schema-only diffs; without it, the engine exited without SQL. The config uses a fixed loopback/port-1 placeholder only to supply that metadata. Neither diff endpoint is a database datasource and no connection is required or performed. Never use this offline config for datasource-based commands or migration application.

Reproduction of the generated portion only, from apps/api (stdout, not an overwrite of the reviewed migration):

```sh
pnpm exec prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script --config prisma.offline.config.ts
```

The reviewed artifact additionally includes all three SQL blocks in section 6, transaction framing and migration comments. Replacing it with a plain generated diff would lose custom integrity protections. Tests compare every model/table/enum, schema-defined indexes, all 35 FK column/target/action tuples and every documented custom SQL block. Financial/default/nullability/cart constraints are explicitly checked. This is static/offline review, not a PostgreSQL parser, live constraint test or concurrency proof.

**Application completed after explicit approval:** on 2026-11-23, the owner-authorized deployment used `pnpm --filter @sellio/api exec prisma migrate deploy --config prisma.config.ts` with CLI-only DIRECT_URL, strict TLS and the verified session pooler. The [deployment record](initial-migration-verification.md) documents the clean/empty-target and access preflight, successful history/checksum, actual definitions and remaining security requirements. Supabase-managed auth/storage schemas were not modified. Never use the placeholder offline config for database access, reset/db push or mark a migration applied to bypass validation. Existing application objects or future migrations require their own approved plan.

Live catalog verification confirms the approved constraints and indexes are deployed without definition discrepancies. Mutating/negative/concurrency integration tests require separate approval. Publication/default existence, reserved-balance sums, same-owner/source checks, immutable record permissions and provider/cancellation/merge workflows remain later services/security work; SQL alone does not implement them. Local migration preparation itself performed no database mutation; the later authorized deployment is recorded separately. No seed, business service, branch, commit or push was included.
