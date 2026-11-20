# Sellio — Database Design Document

**Version:** 0.2 (Draft)  
**Status:** CheckoutAttempt approved as entity 22; detailed schema not approved for migrations  
**Last updated:** 2026-11-19  
**Database:** PostgreSQL  
**ORM:** Prisma  
**Scope:** V1 single-store electronics storefront, reusable commerce core

## 1. Purpose and boundaries

This document specifies Sellio V1's conceptual relational data model, integrity rules, transaction boundaries, and proposed indexes. It supports the [PRD](../architecture/Sellio_PRD.md) and [System Architecture](../architecture/Sellio_SYSTEM_ARCHITECTURE.md). This is a **design specification**, not a deployed schema or a finished Prisma migration. The [implementation specification](DATABASE_IMPLEMENTATION_SPEC.md) provides proposed field refinements, enum and deletion matrices, and schema approval gates B-01 through B-07. The [ERD](ERD.md) is the canonical relationship diagram. Proposed details do not become approved merely by being documented.

The owner approved a separate CheckoutAttempt as the 22nd entity on 2026-11-19; see [ADR-010](../decisions/ADR-010-checkout-attempt.md). Current design targets also establish an initial 30-minute reservation window, persistent payment reconciliation, and exactly one default variant per published product. Detailed mechanisms remain proposals.

V1 supports one store, one initial stock location, USD transactions, authenticated checkout, guest carts, product variants, inventory reservations, order snapshots, and Stripe test payments. Multi-tenancy, multi-location fulfillment, reviews, refunds, and promotions are deferred.

## 2. Modeling conventions

- **Identifiers:** UUID primary keys generated server-side or by the database; avoid exposing sequential IDs as authorization tokens.
- **Time:** `timestamptz` in UTC for audit and expiry fields; display in the user's timezone.
- **Money:** USD and decimal-based values are the target. Proposed `numeric(12,2)` bounds and exact snapshot shape require schema approval; use Prisma `Decimal`, not JavaScript floating-point arithmetic. Store explicit currency on variant prices, orders, order items and payments. Rounding/provider behavior must be settled before checkout; any impact on stored precision or snapshots remains a migration blocker.
- **Naming:** Singular PascalCase Prisma models mapped to snake_case database tables; consistently named foreign keys and unique constraints.
- **Deletion:** Archive products and deactivate variants; preserve orders, payment records, and audit history. Define privacy-driven deletion/anonymization separately.
- **Authorization:** Row ownership and role checks are enforced in the API; database foreign keys are not a substitute for authorization.
- **External IDs:** Provider-generated identifiers must be unique in the appropriate provider namespace.

## 3. Entity inventory

| Domain | Entity | Core responsibility | V1 |
|---|---|---|---|
| Identity | User | Local commercial profile linked to Supabase Auth | Yes |
| Identity | Address | Customer-managed saved shipping address | Yes |
| Catalog | Brand | Optional brand label | Yes |
| Catalog | Category | Hierarchical catalog taxonomy | Yes |
| Catalog | Product | Shared product content and lifecycle | Yes |
| Catalog | ProductCategory | Many-to-many category assignment | Yes |
| Catalog | ProductImage | Ordered images with storage object references | Yes |
| Catalog | ProductOption | Option dimension, e.g., Color | Yes |
| Catalog | ProductOptionValue | Allowed value, e.g., Black | Yes |
| Catalog | ProductVariant | Purchasable SKU and price | Yes |
| Catalog | VariantOptionValue | Selected option values per variant | Yes |
| Inventory | InventoryItem | On-hand and reserved quantities per variant | Yes |
| Inventory | InventoryReservation | Time-limited allocation tied to checkout/order | Yes |
| Inventory | InventoryMovement | Auditable quantity changes | Yes |
| Shopping | Cart | Guest or authenticated shopping cart | Yes |
| Shopping | CartItem | Variant and desired quantity | Yes |
| Checkout | CheckoutAttempt | Durable customer-owned checkout submission, idempotency and recovery | Yes; entity approved |
| Orders | Order | Checkout totals, ownership and lifecycle | Yes |
| Orders | OrderItem | Immutable purchased-item snapshot | Yes |
| Orders | OrderAddress | Immutable shipping-address snapshot | Yes |
| Payments | Payment | Payment attempt/provider state | Yes |
| Payments | PaymentEvent | Webhook deduplication and processing trace | Yes |

There are **22 entities**. No additional entity is authorized by this revision.

## 4. Entity relationship diagram (conceptual)

See [ERD.md](ERD.md) for the complete 22-entity diagram, including CheckoutAttempt, source-cart conversion, accepted payments and inventory movement references. Physical FKs and service-enforced minimum cardinalities are distinguished there.

**Interpretation:** `User` → `Cart` is optional on the cart side because guests can hold carts; `OrderItem.variantId` may be retained as a nullable historical reference, while snapshot fields remain authoritative. Payment events may arrive before local payment association is established, so event linkage can be nullable. The ERD summarizes the domain, not every database constraint.

## 5. Identity model

### User

`id uuid PK`, `auth_id uuid UNIQUE NOT NULL`, `email text NOT NULL`, `first_name text`, `last_name text`, `role enum(CUSTOMER, MANAGER, ADMIN) NOT NULL DEFAULT CUSTOMER`, `created_at`, `updated_at`.

Supabase Auth remains the identity authority. The API verifies access tokens and maps their subject to `auth_id`; it never trusts a client-submitted role. Decide whether `email` is a cached copy of Auth data and how it is synchronized.

### Address

`id uuid PK`, `user_id uuid FK → User NOT NULL`, `recipient_name`, `line1`, `line2`, `city`, `region`, `postal_code`, `country_code`, `phone` (optional), `is_default boolean`, timestamps. Only the owner may read or modify saved addresses. If using a default-address flag, enforce at most one default per user via a **partial unique index** or equivalent transaction-safe design.

## 6. Catalog model

### Brand, Category, Product

- **Brand:** `id PK`, `name`, `slug UNIQUE`.
- **Category:** `id PK`, `name`, `slug UNIQUE`, `parent_id FK → Category NULL`, `status`, timestamps. Prevent self-parenting and category cycles in service logic; a simple FK alone cannot prevent cycles.
- **Product:** `id PK`, `name`, `slug UNIQUE`, `description`, `status enum(DRAFT, ACTIVE, ARCHIVED)`, `brand_id FK → Brand NULL`, timestamps.
- **ProductCategory:** composite `PK(product_id, category_id)` with both foreign keys.
- **ProductImage:** `id PK`, `product_id FK`, `storage_path`, `alt_text`, `position integer`, `is_primary boolean`. Define one primary image per product with a partial unique index if the feature is used.

### Options and variants

- **ProductOption:** `id PK`, `product_id FK`, `name`, `position`; unique `(product_id, name)`.
- **ProductOptionValue:** `id PK`, `option_id FK`, `value`, `position`; unique `(option_id, value)`.
- **ProductVariant:** `id PK`, `product_id FK`, `sku UNIQUE`, `price numeric(12,2)`, `compare_at_price numeric(12,2) NULL`, `status`, `is_default`, timestamps. Check `price >= 0`, and if present `compare_at_price >= 0`.
- **VariantOptionValue:** composite `PK(variant_id, option_value_id)`; links a variant to each selected option value.

Preserve category and variant lifecycle fields. Proposed enum values are CategoryStatus(DRAFT, ACTIVE, ARCHIVED) and VariantStatus(ACTIVE, INACTIVE); they require approval rather than silently substituting `is_active`. Brand archival representation remains unspecified. Exactly one default variant is required for each published/ACTIVE product. A partial unique index enforces at most one; publication and default-switch services enforce existence and validity. Drafts may temporarily lack a default.

Every sellable product has at least one variant; products without configurable options use one default variant. **A relational join table alone does not guarantee that a variant has exactly one value for each product option or that two variants cannot have the same option combination.** Enforce option ownership, completeness, and canonical combination uniqueness in a transactional domain service; consider storing a derived canonical `option_signature` with unique `(product_id, option_signature)` after validation. A variant's price is the current catalog price, not an order-history source of truth.

The proposed signature uses versioned, sorted UUID pairs, a 1024-byte ASCII bound and an explicit optionless value; encoding/bound/update rules await B-02 approval in the implementation specification. PRD CAT-04 attribute filtering is preserved: an approved required-filter list must establish whether option fields suffice or additional JSON storage is needed. Product-only images remain the baseline; variant media is unresolved. Do not silently remove non-option filtering or add a 23rd model.

## 7. Inventory model

### InventoryItem

`id uuid PK`, `variant_id uuid UNIQUE FK → ProductVariant`, `quantity_on_hand integer NOT NULL DEFAULT 0`, `quantity_reserved integer NOT NULL DEFAULT 0`, `updated_at`. Database checks: `quantity_on_hand >= 0`, `quantity_reserved >= 0`, and `quantity_reserved <= quantity_on_hand`. Available-to-sell = on-hand − reserved.

Create every variant and its balance atomically, including inactive/default variants. A unique child FK enforces at most one; service creation/publication validates existence. A zero balance does not by itself prohibit catalog publication.

### InventoryReservation

`id uuid PK`, `inventory_item_id FK`, `order_id FK → Order NULL`, `quantity integer > 0`, `status enum(ACTIVE, CONSUMED, RELEASED, EXPIRED)`, `expires_at`, timestamps. A checkout reference or order reference must be used to make reservation creation idempotent; finalize the precise checkout key before implementation.

Target initial duration: **30 minutes**, stored as an actual expiry, coordinated with the eventual Stripe integration. Proposed B-03 refinement adds required `checkout_attempt_id` and makes `order_id` required because local order/reservation creation is atomic. Proposed unique `(checkout_attempt_id, inventory_item_id)` prevents duplicate allocation for a normalized line. This is an explicit refinement of the original nullable order link, awaiting approval.

### InventoryMovement

`id uuid PK`, `inventory_item_id FK`, `quantity_delta integer`, `reason enum(RECEIPT, ADJUSTMENT, SALE, RETURN, CORRECTION)`, `order_id FK NULL`, `actor_user_id FK NULL`, `created_at`, `note`. Movements are append-only audit entries; updates to balances and movement inserts occur in the same transaction. Reserving stock changes `quantity_reserved` but not `quantity_on_hand`; consumption reduces **both** by the reserved quantity.

The ERD now includes the original Order/User movement references. Proposed B-03 adds nullable `reservation_id` with one SALE movement per reservation; service transactions validate quantity/order correspondence. Reserve/release operations do not create on-hand movements. FK deletion restrictions alone do not make the ledger append-only.

### Concurrency invariant

Use row-level locking or conditional updates inside a database transaction, e.g., only reserve `q` if `quantity_on_hand - quantity_reserved >= q`. On expiration, release a reservation exactly once. Payment success, reservation expiration, and cancellation must be reconciled safely: a late successful payment cannot simply be ignored or fulfill unreserved stock. Define recovery/refund/manual-review policy before production.

Deadline crossing, worker release, actual provider success and webhook receipt are distinct. Delayed delivery is not proof of late payment. Never consume released stock automatically. Record successful payments truthfully and persist reconciliation even when fulfillment is blocked. Services maintain the cross-row equality between reserved balances and ACTIVE reservation totals; ordinary row CHECKs cannot enforce it.

## 8. Cart model

- **Cart:** `id PK`, `user_id FK → User NULL`, `guest_token_hash NULL`, `status enum(ACTIVE, CONVERTED, ABANDONED)`, timestamps. Guest identity is an opaque secret handled securely; do not use predictable cart IDs as authorization.
- **CartItem:** `id PK`, `cart_id FK`, `variant_id FK`, `quantity integer > 0`, timestamps; unique `(cart_id, variant_id)`.

Adding an item does not reserve stock. Cart totals are estimates; the server revalidates current prices, variant availability, taxes, and shipping at checkout. Guest-to-user cart merge policy is an open decision.

### CheckoutAttempt — entity approved; detailed fields proposed

`id UUID PK`, required `user_id` and `cart_id` FKs, captured `cart_revision`, `idempotency_key`, versioned `request_fingerprint`, minimal immutable `request_snapshot`, lifecycle `status`, optional unique `order_id` FK, retry/error/lease/fencing metadata and retention timestamps. Unique `(user_id, idempotency_key)` protects durable replay. This is a logical submission, not a provider payment attempt.

The implementation specification section 3 gives concrete field types and proposed states. Same input/key resumes the same attempt/order; changed input conflicts. Never recalculate a replay fingerprint against mutable current catalog/address/cart data. Proposed `Cart.revision` records line changes. Recovery uses guarded ownership and stable operation IDs; unknown provider outcomes are reconciled outside DB transactions.

Proposed `Order.source_cart_id NOT NULL UNIQUE` and a live-attempt partial unique index prevent duplicate conversion across different keys and after terminal-record cleanup. Under the proposed policy, pending-order creation freezes/converts its source cart. Later failure does not reactivate that historical cart; an explicit replacement cart can preserve the shopping experience. This policy, owner-matching composite FKs, retention/redaction and guest ownership remain B-01/B-06 decisions. Financially linked idempotency mappings must not disappear under ordinary retry-record cleanup.

## 9. Orders model

### Order

`id uuid PK`, `order_number text UNIQUE`, `user_id uuid FK → User NOT NULL` (authenticated V1 checkout), `status enum(PENDING_PAYMENT, PAID, PROCESSING, SHIPPED, DELIVERED, CANCELLED, PAYMENT_FAILED)`, `currency char(3)`, `subtotal`, `shipping_total`, `tax_total`, `discount_total`, `grand_total` (all numeric), `created_at`, `updated_at`, `paid_at NULL`.

Proposed checks: monetary totals nonnegative; `grand_total = subtotal + shipping_total + tax_total - discount_total` subject to the chosen rounding rules. Order number generation must be concurrency-safe. Separate fulfillment status from payment status if the lifecycle becomes more complex; do not infer payment success solely from `Order.status`.

Retain the existing order enum and separate Payment.status. Proposed fields are `source_cart_id UNIQUE NOT NULL`, optional unique `accepted_payment_id`, and persistent reconciliation fields; see B-01/B-04. An accepted-payment composite FK must reference a Payment belonging to this order. Required order ownership is preserved: retain/anonymize local users rather than nulling or cascading their orders.

### OrderItem and OrderAddress

- **OrderItem:** `id PK`, `order_id FK`, `variant_id FK NULL`, `product_name_snapshot`, `sku_snapshot`, `options_snapshot jsonb`, `unit_price`, `quantity > 0`, `line_total`, `currency`. Preserve snapshots even if the catalog entry is later archived.
- **OrderAddress:** `id PK`, `order_id UNIQUE FK`, shipping recipient/address fields copied at purchase time. Never reference a mutable saved address as the only shipping source.

Order snapshots and financial totals are immutable after placement except for explicit, auditable corrections. Tax breakdown detail may require an additional snapshot field/table depending on provider output.

The current target freezes pending-order snapshots only after complete authoritative totals. Proposed B-05 adds line tax/discount amounts and order tax/shipping-method JSON snapshots without another entity. Exact precision, line-total semantics, nullability and provider finalization must be approved; there is no automatic permission to mutate snapshots when a later provider quote differs. Any correction process requires separate audit approval.

## 10. Payments and provider events

### Payment

`id PK`, `order_id FK`, `provider enum(STRIPE)`, `provider_payment_id NULL`, `provider_checkout_session_id NULL`, `amount`, `currency`, `status enum(PENDING, REQUIRES_ACTION, SUCCEEDED, FAILED, CANCELLED)`, timestamps. An order may have multiple attempts. Unique provider identifiers when present; store no card numbers or sensitive payment credentials.

Multiple actual settlements must remain recordable as SUCCEEDED. Never add uniqueness on SUCCEEDED per order. Proposed Order.accepted_payment_id designates at most one fulfillment settlement; it does not erase an extra/late payment. Proposed reconciliation status NONE/REQUIRED/RESOLVED, reason, detection/resolution timestamps, resolver User FK and sanitized resolution note live on Order and Payment. These fields and provider retry/status mapping await B-04 approval.

### PaymentEvent

`id PK`, `provider`, `provider_event_id`, `payment_id FK NULL`, `event_type`, `processing_status enum(RECEIVED, PROCESSED, FAILED)`, `received_at`, `processed_at NULL`, `error_code NULL`; unique `(provider, provider_event_id)`. Store only minimal safe metadata needed for diagnosis. Verify Stripe signatures against the raw request body before processing. Event handlers must be idempotent and tolerate out-of-order delivery.

Persist receipts separately from effect execution; effects and PROCESSED marking commit together. Failure diagnostics must survive rollback; a duplicate receipt may still need retry. Proposed provider-object/recovery metadata supports events arriving before association. Payment/reservation/order guards prevent distinct events from repeating one settlement's effects.

## 11. Indexes, transactions, and lifecycle

### Proposed indexes

| Table | Index / constraint | Purpose |
|---|---|---|
| User | UNIQUE(auth_id) | Resolve authenticated identity |
| Product | UNIQUE(slug), INDEX(status, created_at) | Public catalog listing |
| Category | UNIQUE(slug), INDEX(parent_id) | Category navigation |
| ProductVariant | UNIQUE(sku), INDEX(product_id, status) | SKU and variant lookup |
| ProductCategory | PK(product_id, category_id), INDEX(category_id, product_id) | Both traversal directions |
| CartItem | UNIQUE(cart_id, variant_id) | Prevent duplicate lines |
| InventoryItem | UNIQUE(variant_id), CHECK quantities | One V1 stock balance per variant |
| InventoryReservation | INDEX(status, expires_at) | Expiration worker |
| Order | UNIQUE(order_number), INDEX(user_id, created_at) | Customer order history |
| Payment | UNIQUE(provider, provider_payment_id) WHERE NOT NULL | Provider reconciliation |
| PaymentEvent | UNIQUE(provider, provider_event_id) | Webhook deduplication |

Search and filtering indexes should be based on real query plans; PostgreSQL full-text search may be sufficient for V1. Prisma schema support varies for partial indexes and database checks; use reviewed SQL migrations where required.

Implementation specification sections 8–10 are the proposed complete FK/deletion/constraint/index plan, including checkout replay/live-cart guards, accepted-payment membership, primary/default uniqueness and SALE deduplication. Exact-one defaults, required inventory balances, cross-row totals, category acyclicity and immutable records also require services/permissions. Verify native PostgreSQL feature support for the selected Prisma major rather than assuming all checks/partial indexes require custom SQL.

### Critical transaction boundaries

1. **Reserve stock and create pending order:** validate cart/prices; atomically reserve quantities and persist order snapshots; use a checkout idempotency key.
2. **Confirm payment:** verified event updates payment/order state and consumes stock exactly once.
3. **Expire or cancel:** atomically release active reservations; handle payment race conditions explicitly.
4. **Admin inventory adjustment:** update balance and append movement together; reject changes that would reduce on-hand below reserved quantity.

Do **not** hold a database transaction open during a network call to Stripe. Use a durable local state machine and reconciliation strategy across the DB/payment-provider boundary.

## 12. Open decisions and migration gate

The entity count is settled at **22**. This revision proposes a narrower migration gate separating persistent schema from later service behavior; the owner must approve that gate and the detailed schema before migrations.

Schema-blocking decisions are tracked once in the [implementation specification section 12](DATABASE_IMPLEMENTATION_SPEC.md#12-remaining-schema-decisions):

1. **B-01:** CheckoutAttempt field/state/ownership contract and durable cart conversion.
2. **B-02:** Catalog lifecycle values, option signatures, required filters/attribute storage and media ownership.
3. **B-03:** Reservation checkout/order nullability and sale-movement references.
4. **B-04:** Accepted settlement, persistent reconciliation and event/provider-state mapping.
5. **B-05:** Decimal precision and complete immutable financial/shipping snapshot shape.
6. **B-06:** All FK actions, privacy-compatible required order ownership and historical enforcement.
7. **B-07:** Compatible toolchain, native/custom SQL approach and approved initial migration scope.

The 30-minute initial reservation target, USD/Decimal direction, exactly-one published default and preserved history are established design targets. Worker cadence, exact retry/guest retention durations, merge/caps, cancellation permissions, refund operations, tax/rate providers, geography and rounding mechanics can follow later **only if approved storage is sufficient**. Decide them before the affected feature ships. Provider/tax/shipping/privacy choices remain migration blockers when they change persistent fields, constraints or cardinalities; no unapproved shipment, attribute or refund model is assumed.

### Acceptance criteria for database design

- Every FK and cardinality is reviewed against V1 user journeys.
- Constraints cover nonnegative balances, unique SKU, duplicate cart items, and provider-event deduplication.
- Concurrent checkout and webhook retry scenarios have integration tests planned.
- Order and address snapshots remain historically accurate after profile/catalog changes.
- Prisma models and SQL migrations match the approved ERD, including non-Prisma-native constraints.

## 13. Next implementation steps

1. Resolve §12 decisions that affect schema shape.
2. Review the ERD and approve V1 relationships.
3. Generate Prisma models and a reviewed initial SQL migration.
4. Seed a small fictional electronics catalog with variants.
5. Add integration tests for inventory concurrency, order snapshots, and payment-event idempotency.

---

**Document status:** Draft. No tables, indexes, or migrations are claimed to exist yet.

