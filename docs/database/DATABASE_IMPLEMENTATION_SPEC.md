# Sellio — Database Implementation Specification

**Version:** 0.2 — 2026-11-19  
**Status:** Initial migration generated locally for review under owner approval; no database connected or migration applied.

**Scope:** Single store, one inventory location, PostgreSQL + Prisma + NestJS.

## 1. Authority and decision status

**Migration-readiness approvals (2026-11-20):** the owner approved gross line accounting with nullable tax/discount breakdowns; required order tax/shipping amounts with zero defaults; nullable saved/historical line2/phone/region; one active customer cart, unique non-null guest token hashes and exactly one cart owner type; and deferral of extra Brand archival fields, non-option attribute storage and variant media. These decisions supersede conflicting proposal/gate language below. The [initial migration](../../apps/api/prisma/migrations/20261120000000_initial/migration.sql) contains the full baseline plus custom SQL. No schema-readiness blocker from those four gates remains; connecting/applying still requires explicit approval.

**Part A update (2026-11-20):** the owner authorized installing stable Prisma and implementing the detailed concrete contracts consistent with the approved V1 directions. [PRISMA_FOUNDATION.md](PRISMA_FOUNDATION.md) records the implemented choices, provisional nullability, service-enforced ownership alternative and future SQL. The tables below retain the design rationale; unresolved choices are not converted into invented business rules. The subsequent migration-preparation approval authorizes local SQL generation; database connection/application and later policies still require separate approval. Where older planning language below says installation is unauthorized or a concrete field is proposed, this scoped Part A authorization supersedes it, not the outstanding migration gate.

Read the [PRD](../architecture/Sellio_PRD.md), [architecture](../architecture/Sellio_SYSTEM_ARCHITECTURE.md), [database design](Sellio_DATABASE_DESIGN.md), [ERD](ERD.md), and [ADRs](../decisions/).

- **Approved:** CheckoutAttempt is the 22nd entity, separate from Payment; see [ADR-010](../decisions/ADR-010-checkout-attempt.md).
- **Requested targets:** one balance per variant; transactional reservations; initial 30-minute reservation window coordinated with Stripe; independent order/payment states; multiple payment attempts; persistent reconciliation; USD and decimal money; immutable snapshots; exactly one default variant per published product; historical financial retention and catalog archival.
- **Proposed:** new field layouts, enums, referential actions and service policies below. Entity approval does not approve every implementation detail.
- **Unselected:** exact PostgreSQL/Prisma versions, hosting, Stripe integration, tax/shipping providers and privacy policy. Existing ADR statuses are preserved.

The earlier 15-minute proposal is superseded by the requested 30-minute target. There is no mandatory 21-model cap and no established free-shipping-over-$75 rule.

## 2. Final model and primary-key inventory

UUID id PKs apply except the two explicit joins. Use singular PascalCase Prisma models, explicit snake_case table/column mappings, and UTC timestamptz. Select UUID generation with the toolchain.

| Domain | Models | Primary-key exception |
| --- | --- | --- |
| Identity | User, Address | None |
| Catalog | Brand, Category, Product, ProductCategory, ProductImage | ProductCategory PK(product_id, category_id) |
| Options | ProductOption, ProductOptionValue, ProductVariant, VariantOptionValue | VariantOptionValue PK(variant_id, option_value_id) |
| Inventory | InventoryItem, InventoryReservation, InventoryMovement | None |
| Shopping | Cart, CartItem | None |
| Checkout | CheckoutAttempt | None |
| Orders | Order, OrderItem, OrderAddress | None |
| Payments | Payment, PaymentEvent | None |

Exactly 22 entities. No tenant, warehouse, generic attribute, shipment, refund or audit-log entity is authorized. A requirement needing more storage remains an explicit scope decision.

## 3. CheckoutAttempt — proposed persistence contract

One logical checkout submission can create one order, which can have multiple Payment attempts.

| Field | Proposed type / requirement |
| --- | --- |
| id | UUID PK |
| user_id | UUID NOT NULL FK User; authenticated owner |
| cart_id | UUID NOT NULL FK Cart; immutable source |
| cart_revision | integer NOT NULL, >= 0; captured Cart.revision |
| idempotency_key | varchar(128) NOT NULL; UNIQUE(user_id, idempotency_key) |
| request_fingerprint | char(64) NOT NULL; SHA-256 of canonical versioned request bytes |
| fingerprint_version | smallint NOT NULL, > 0 |
| request_snapshot | jsonb NOT NULL; minimal immutable normalized recovery input |
| status | CheckoutAttemptStatus NOT NULL |
| order_id | UUID NULL UNIQUE FK Order; never relink to a different order |
| processing_token | UUID NULL; recovery fencing token |
| processing_lease_expires_at | timestamptz NULL |
| retry_count | integer NOT NULL DEFAULT 0, >= 0 |
| next_retry_at, retention_expires_at | timestamptz NULL; distinct from reservation expiry |
| last_error_code | text NULL; sanitized |
| created_at, updated_at | timestamptz NOT NULL |

Proposed accompanying fields: Cart.revision integer DEFAULT 0 and Order.source_cart_id UUID NOT NULL UNIQUE FK Cart. Cart item changes increment revision transactionally.

### Input stability, retries and recovery

1. Atomically insert/claim the customer/key record before effects. Same key and same stable input returns its original result/in-progress state; changed input returns conflict.
2. Canonical input contains sorted variant UUID/quantity pairs, cart ID/revision, submitted address and shipping-method inputs. Snapshot actual submitted address values, not only a mutable saved-address ID. Freeze encoding/version before implementation.
3. Do not fingerprint current catalog prices, current stock or later address edits on replay. A fingerprint identifies input, not authorized pricing. First execution calculates authoritative totals; retries return the frozen order. Repricing requires an explicit new submission.
4. Recover interrupted processing with expiring leases and a new fencing token. All subsequent writes verify ownership; lease expiry alone must not permit stale workers to repeat effects.
5. Create local order, snapshots, all reservations and payment record in one transaction. Stripe calls occur after commit using a durable per-payment-operation key. Persist provider references; a timeout is uncertain, not definitive failure.
6. Same submission resumes its existing attempt/order. A retry does not automatically create a new Payment. Concurrent different keys for one cart require locking plus durable conversion protection.
7. Minimize and protect request_snapshot personal data. Never store card data, credentials or tokens. Purging terminal retry records must not remove the only durable financial-operation mapping; retain linked attempts/minimal tombstone fields within this entity.

Proposed 48-hour client-key retention remains unapproved and is not financial retention.

### Cart conversion proposal — B-01

Freeze and mark the source cart CONVERTED when its pending order is created. UNIQUE(Order.source_cart_id) prevents another order from that cart permanently, including after attempt cleanup. A partial unique live-attempt index prevents concurrent submissions before an order exists.

Failure before order creation leaves the cart usable. After order creation, do not reactivate/reconvert the historical source cart; an explicit customer action can create a replacement cart/new ID from its items. This replacement policy requires approval. Merge UX/caps and automatic replacement are not assumed.

Validate that cart, attempt and order belong to the same customer and refer to the same source cart. Proposed composite ownership FKs can use Cart(id, user_id) and Order(id, user_id) supporting unique keys; their adoption is B-01. A simple FK alone does not enforce matching ownership. Order.user_id remains required; there is no FK to an assumed Supabase auth database.

## 4. Enum plan

| Enum | Values | Status |
| --- | --- | --- |
| UserRole | CUSTOMER, MANAGER, ADMIN | Existing; default CUSTOMER |
| ProductStatus | DRAFT, ACTIVE, ARCHIVED | Existing |
| CategoryStatus | DRAFT, ACTIVE, ARCHIVED | Proposed values; field already documented |
| VariantStatus | ACTIVE, INACTIVE | Proposed values; field already documented |
| CartStatus | ACTIVE, CONVERTED, ABANDONED | Existing |
| CheckoutAttemptStatus | RECEIVED, PROCESSING, AWAITING_PAYMENT, COMPLETED, FAILED, CANCELLED, EXPIRED | Proposed |
| ReservationStatus | ACTIVE, CONSUMED, RELEASED, EXPIRED | Existing |
| InventoryMovementReason | RECEIPT, ADJUSTMENT, SALE, RETURN, CORRECTION | Existing; RETURN does not implement returns |
| OrderStatus | PENDING_PAYMENT, PAID, PROCESSING, SHIPPED, DELIVERED, CANCELLED, PAYMENT_FAILED | Existing |
| PaymentStatus | PENDING, REQUIRES_ACTION, SUCCEEDED, FAILED, CANCELLED | Existing; provider mapping unresolved |
| PaymentProvider | STRIPE | Existing; test mode |
| PaymentEventStatus | RECEIVED, PROCESSED, FAILED | Existing |
| ReconciliationStatus | NONE, REQUIRED, RESOLVED | Proposed on Order and Payment |

### Transition contract — service rules, not enum guarantees

| Entity / transition | Guard and effect |
| --- | --- |
| Checkout RECEIVED -> PROCESSING | Claim fenced processing ownership |
| PROCESSING -> PROCESSING | Recovery/retry, same order/effect identities |
| PROCESSING -> AWAITING_PAYMENT | Local order/payment/reservations persisted; provider creation is recoverable |
| AWAITING_PAYMENT -> COMPLETED | Accepted payment and stock consumption completed |
| Nonterminal checkout -> FAILED/CANCELLED/EXPIRED | Definitive approved terminal policy and release/reconciliation; a network timeout is not terminal failure |
| Terminal checkout replay | Return same result; late financial truth can require reconciliation without reopening submission |
| Order PENDING_PAYMENT -> PAID | Verified success, expected amount/currency, accepted settlement and stock consumption |
| PAID -> PROCESSING -> SHIPPED -> DELIVERED | Authorized staff service; no implicit shipment on payment |
| PENDING_PAYMENT -> CANCELLED/PAYMENT_FAILED | Approved order closure/window policy, not one failed card interaction |
| Payment PENDING <-> REQUIRES_ACTION | Verified provider state/reconciliation only |
| Payment nonterminal -> SUCCEEDED/FAILED/CANCELLED | Provider mapping distinguishes retryable interaction from terminal provider-object failure |
| SUCCEEDED -> SUCCEEDED | Duplicate/stale failures cannot erase success |
| Late/unexpected verified success | Record SUCCEEDED and persistent reconciliation; do not force an invalid order transition |

Define whether one Payment row represents one provider payment object or one authorization interaction. Retrying a provider object must not duplicate its unique provider ID or conceal later success. Provider processing can map to PENDING if explicitly specified. A browser redirect never proves payment. Customer cancellation permissions and staff refund operations remain proposals, not schema-implied features.

## 5. Inventory and 30-minute initial window

Persist actual reservation expires_at; do not hardcode TTL in a database default. All lines of a checkout share the intended deadline. Coordinate provider lifetime with local reservation creation: a 30-minute provider lifetime measured later is not automatically the same deadline. Provider selection and recovery mechanics must be settled before checkout.

Create each variant and its InventoryItem in the same service transaction, including inactive and default variants. The unique variant FK prevents duplicates but does not guarantee a child exists. Publication verifies the balance/default invariants; no positive-stock publication threshold is assumed.

Proposed refinements (B-03):
- InventoryReservation.checkout_attempt_id and order_id become required FKs because the checkout transaction creates all three together. The original nullable order FK is explicitly proposed to become required.
- UNIQUE(checkout_attempt_id, inventory_item_id) gives one reservation per normalized line.
- InventoryMovement.reservation_id is nullable; one SALE movement per reservation via partial unique index. Preserve original optional order_id and actor_user_id. SALE requires reservation_id; service validates order/quantity correspondence.

| Reservation action | Atomic balance/history changes |
| --- | --- |
| Create ACTIVE | Guard available >= quantity; increment reserved; all checkout lines commit or roll back together |
| ACTIVE -> CONSUMED | Decrement on_hand and reserved; append SALE; accept settlement and update order/checkout/event |
| ACTIVE -> RELEASED | Decrement reserved only, under approved cancellation/terminal-failure policy |
| ACTIVE -> EXPIRED | Decrement reserved only after deadline, exactly once |
| Terminal replay | No repeated balance or movement effects |

Lock in consistent variant-ID order; use guarded transitions and bounded conflict retries. Staff on-hand changes append reasoned movements and cannot reduce on_hand below reserved. Reservations/releases do not create fictitious on-hand movements.

Provider success time, webhook receipt time, deadline crossing and worker release are distinct. If time passed but stock is still ACTIVE, lock and inspect the actual state; do not infer release from time alone. Delayed delivery is not necessarily late payment. Once released, never consume unreserved stock automatically. Record provider success and reconciliation; refund/reacquisition/manual-resolution policy remains explicit.

Maintain reserved = sum(ACTIVE reservation quantities) in services. An ordinary row CHECK cannot enforce this. Expired-by-time ACTIVE rows still count until transitioned; availability queries must not pretend counters were released.

## 6. Acceptance and persistent reconciliation — B-04 proposal

Multiple Payment rows may truthfully be SUCCEEDED. Never add uniqueness on successful payments per order.

- Order.accepted_payment_id UUID NULL UNIQUE references the one settlement accepted for fulfillment. Proposed composite FK (accepted_payment_id, Order.id) -> Payment(id, order_id), supported by UNIQUE(Payment.id, Payment.order_id), ensures same-order association. Insert order with NULL, then payment, then acceptance; migration must handle this cycle.
- Both Order and Payment gain reconciliation_status (default NONE), reconciliation_reason, reconciliation_detected_at, reconciliation_resolved_at, reconciliation_resolved_by_user_id (nullable User FK) and sanitized reconciliation_resolution_note.
- A late or extra actual settlement stays SUCCEEDED; mark payment/order REQUIRED without another sale or stock consumption. RESOLVED records operational resolution without pretending an automated refund exists. Order aggregate reconciliation is service-maintained; an accepted payment cannot be silently replaced.
- Persist verified PaymentEvent receipts before processing. Commit effects and PROCESSED together. Record processing failure outside the rolled-back effects transaction. RECEIVED/FAILED events require durable recovery; duplicate receipt is not proof of completed processing.
- Events may precede local association. Proposed safe provider_object_id metadata supports relinking; exact field/retry metadata is B-04. Unique event ID alone cannot prevent different events for the same settlement from repeating effects.

Verify signatures/raw body, provider identity, amount/currency and order linkage. No provider network call runs inside a DB transaction. FKs/unique references and locked transitions complement each other; no unique index proves payment success or stock availability.

## 7. Catalog and immutable financial data

Preserve Product.status. Every ACTIVE/published product has exactly one valid purchasable default variant and inventory balance. Drafts may temporarily lack a default. Partial uniqueness enforces at most one; publication/default-switch services enforce existence transactionally.

Category and variant lifecycle fields already exist; Part A uses the section 4 enums without replacing them with is_active. The owner approved keeping Brand unchanged and deferring extra archival fields from the baseline.

Proposed option_signature: prefix v1| plus sorted lowercase UUID pairs optionUUID:valueUUID separated by semicolons; optionless signature is v1|. Proposed maximum 1024 ASCII bytes and UNIQUE(product_id, option_signature), NOT NULL after validation. Bound/encoding/case rules require approval. Never truncate. Services validate ownership, one value per option, completeness and equality to the signature. Option-set edits regenerate all affected combinations transactionally; never change historical order options.

Retain ProductImage.position/is_primary and at-most-one primary image. Product-only media is the approved initial scope; variant-specific media and non-option attribute storage are explicitly deferred. PRD CAT-04 remains a later delivery requirement, not permission to add speculative entities to this migration. Supabase Storage remains planned; no integration is implemented.

USD/Decimal are targets. Proposed numeric(12,2) applies to variant price/compare-at price, order/line amounts and payments. Proposed explicit char(3) currency on ProductVariant, Order, OrderItem and Payment has a USD CHECK. Monetary bounds, tax-inclusive pricing and snapshot shape are B-05; binary floating-point calculations are prohibited.

Preserve original order totals and line/address snapshots. Approved line_total = quantity * unit_price is gross before tax/discount; subtotal sums gross lines. Line tax/discount allocations remain nullable and informational; do not count them again in grand_total. Order shipping_total/tax_total are required Decimal(12,2), default zero for applicable no-charge/zero-tax cases. Grand_total = subtotal + shipping_total + tax_total - discount_total. Optional order tax/shipping descriptive JSON is retained. Unknown line detail is not zero. Rounding, tax/shipping calculation and quote finalization remain later service requirements; no universal rate or threshold is established.

Freeze snapshots at pending-order creation after complete authoritative totals. If the selected provider determines different totals afterward, approve a quote/finalization protocol rather than silently altering the order. API decimal serialization/minor-unit conversion is explicit. Order.user_id is required; saved-address/catalog edits and deletion cannot rewrite historical purchases. Any financial correction requires an approved auditable process.

## 8. Proposed foreign-key deletion matrix — B-06

All IDs are immutable; propose ON UPDATE RESTRICT. R = RESTRICT, N = SET NULL, C = CASCADE on parent deletion. No action grants permission to expose destructive APIs.

| Child FK -> parent | Null? | Delete |
| --- | --- | --- |
| Address.user_id -> User | No | C |
| Category.parent_id -> Category | Yes | R |
| Product.brand_id -> Brand | Yes | R |
| ProductCategory.product_id / category_id -> Product / Category | No | C / C |
| ProductImage.product_id -> Product | No | C |
| ProductOption.product_id -> Product | No | R |
| ProductOptionValue.option_id -> ProductOption | No | R |
| ProductVariant.product_id -> Product | No | R |
| VariantOptionValue.variant_id / option_value_id -> ProductVariant / ProductOptionValue | No | R / R |
| InventoryItem.variant_id -> ProductVariant | No | R |
| Cart.user_id -> User | Yes | R; approved exclusive ownership prohibits automatic owner removal |
| CartItem.cart_id / variant_id -> Cart / ProductVariant | No | C / R |
| CheckoutAttempt.user_id / cart_id -> User / Cart | No | R / R |
| CheckoutAttempt.order_id -> Order | Yes | R |
| Order.user_id / source_cart_id -> User / Cart | No | R / R |
| Order.accepted_payment_id -> Payment | Yes | R |
| OrderItem.order_id / variant_id -> Order / ProductVariant | No / Yes | R / N |
| OrderAddress.order_id -> Order | No | R |
| Payment.order_id -> Order | No | R |
| PaymentEvent.payment_id -> Payment | Yes | R |
| InventoryReservation.inventory_item_id / checkout_attempt_id / order_id -> InventoryItem / CheckoutAttempt / Order | No | R / R / R |
| InventoryMovement.inventory_item_id / order_id -> InventoryItem / Order | No / Yes | R / R |
| InventoryMovement.actor_user_id / reservation_id -> User / InventoryReservation | Yes | N / R |
| Order / Payment.reconciliation_resolved_by_user_id -> User | Yes | N |

Nullable event linkage permits arrival-before-association, not deletion of payment history. Product/category/variant archival is normal; permissible draft cleanup must clear dependent configuration explicitly. Required order ownership uses retained/anonymized local users; never SET NULL a required order owner. Supabase account deletion is a separate lifecycle, not a cross-database cascade.

RESTRICT does not prevent deleting an unreferenced child, editing snapshots or rewriting movements. Services and least-privilege DB permissions protect immutable/append-only records. Approve whether additional DB triggers are required. Cascade is limited to true saved-data/configuration joins; never financial history. Optional composite FKs must not SET NULL parent PKs/required user IDs inadvertently.

## 9. Unique constraints and PostgreSQL checks

Approved ownership CHECK: exactly one of cart.user_id and guest_token_hash is non-null. The User FK uses RESTRICT instead of SET NULL to avoid orphaning the cart. Guest claiming must set user_id and clear the token in one statement; merge/select an existing active customer cart transactionally rather than violate uniqueness temporarily.

Existing: User(auth_id); Brand/Category/Product(slug); ProductVariant(sku); ProductOption(product_id, name); ProductOptionValue(option_id, value); InventoryItem(variant_id); CartItem(cart_id, variant_id); Order(order_number); OrderAddress(order_id); both join PKs; Payment(provider, provider_payment_id) and (provider, provider_checkout_session_id) when present; PaymentEvent(provider, provider_event_id). Email uniqueness is not assumed.

Proposed: CheckoutAttempt(user_id, idempotency_key), CheckoutAttempt(order_id), Order(source_cart_id), Order(accepted_payment_id), ProductVariant(product_id, option_signature), InventoryReservation(checkout_attempt_id, inventory_item_id), and supporting Payment(id, order_id) / optional Cart(id, user_id), Order(id, user_id) keys for composite FKs.

Proposed partial unique indexes:
- Address(user_id) WHERE is_default.
- ProductImage(product_id) WHERE is_primary.
- ProductVariant(product_id) WHERE is_default (at most one even on drafts).
- Cart(user_id) WHERE status = ACTIVE AND user_id IS NOT NULL (approved).
- CheckoutAttempt(cart_id) WHERE status IN (RECEIVED, PROCESSING, AWAITING_PAYMENT).
- InventoryMovement(reservation_id) WHERE reason = SALE AND reservation_id IS NOT NULL.
- Cart(guest_token_hash) WHERE guest_token_hash IS NOT NULL (approved).

CHECK candidates: nonnegative required money; positive item/reservation quantities; 0 <= reserved <= on_hand; nonnegative revisions/retry counts; positive fingerprint_version; bounded nonempty key/signature; Category.parent_id != id; SALE requires reservation_id; currency = USD; approved same-row order-total equation. Required fields also need NOT NULL.

Service invariants: default/balance existence, category acyclicity, option ownership/completeness, reservation sums, valid payment acceptance, cross-row order totals and immutable snapshots. Do not claim ordinary CHECKs enforce these. Use supported Prisma-major native features or reviewed custom migration SQL; do not assume partial indexes/CHECKs are unsupported in every major.

## 10. Non-unique indexes

Retain Product(status, created_at), Category(parent_id), ProductVariant(product_id, status) after enum approval, ProductCategory(category_id, product_id), InventoryReservation(status, expires_at), Order(user_id, created_at).

Proposed access indexes: CheckoutAttempt(status, next_retry_at), CheckoutAttempt(retention_expires_at), CheckoutAttempt(cart_id, created_at); Payment(order_id, created_at), Payment(reconciliation_status, updated_at); Order(reconciliation_status, updated_at); PaymentEvent(processing_status, received_at); InventoryReservation(order_id), InventoryReservation(inventory_item_id); InventoryMovement(inventory_item_id, created_at); OrderItem(order_id); CartItem(variant_id); Product(brand_id); ProductImage(product_id, position).

Evaluate FK access and existing left-prefix coverage before adding redundant indexes. Unique constraints already supply indexes. Search/JSON/trigram indexes await approved filters and query plans.

## 11. Migration, environment, seeds and verification plan

1. Approve B-01 through B-07, exact fields, ERD and FK actions. The intended baseline includes all 22 entities; any phased subset needs explicit scope approval.
2. Part A selected and pinned stable Prisma CLI/client/adapter 7.10.1 against Node 22.22.3, TypeScript 5.9.3, NestJS 12 and ESM. PostgreSQL provisioning/version and migration execution remain pending. See the foundation record for configuration and offline verification.
3. Keep definitions, migrations, seeds and client integration under apps/api, using infrastructure/module boundaries. Public DTOs remain in packages/types; no frontend Prisma imports or unrelated API restructuring.
4. Use isolated development/test databases. DATABASE_URL remains server-only and uses the Supabase shared transaction pooler for runtime queries; CLI datasource.url uses only DIRECT_URL, the shared session pooler. Explicitly configure CLI environment loading; Nest ConfigModule does not configure the Prisma CLI. See [Supabase connection configuration](SUPABASE_CONNECTIONS.md). Connecting and applying migrations require separate explicit approval.
5. Generate one reviewed baseline migration only after explicit authorization. Include approved integrity indexes/checks and resolve cyclic Order/Payment FK creation order. Never replace deployment migration history with production db push.
6. Inspect SQL, replay on empty disposable PostgreSQL, test constraints/indexes and forward-fix/restore strategy. No destructive reset of persistent environments.
7. Seed deterministic fictional brands/categories, optionless/default and configurable products, stock balances with receipt movements. No live identities, staff privilege grants, real financial data or required Supabase calls. Race/financial fixtures stay in isolated tests.
8. Extend CI with PostgreSQL, migrations and database tests. Mutating migration/seed tasks are non-cacheable; ensure generation/cache correctness. Existing lint/typecheck/build remain.
9. Implement actual inventory, checkout, payment and fulfillment services in later bounded tasks.

Required future tests: ownership/FKs; key replay/conflict; stale-worker fencing; two keys/one cart; replay after retention; option signatures/default existence; invalid money/quantities; multi-line rollback; last-unit race; expiry/delayed webhook; duplicate distinct events; multiple true settlements; persistent reconciliation; snapshots/deletion/history preservation.

## 12. Decision registry and remaining application work

| ID | Design area | Initial migration resolution |
| --- | --- | --- |
| B-01 | Checkout fields/states/ownership and conversion | Section 3; unique frozen source cart, replacement policy, composite FK choice |
| B-02 | Catalog lifecycle/signatures/filter shape | Existing implemented lifecycle/signature contracts retained; extra Brand archival, non-option attributes and variant media explicitly deferred |
| B-03 | Reservation and movement links | Required order/attempt references, line uniqueness, reservation-linked SALE movements |
| B-04 | Acceptance/reconciliation/event recovery | Same-order accepted payment, persistent reconciliation fields, provider-object linking and provider-state mapping |
| B-05 | Monetary precision and snapshot contract | Approved numeric(12,2), USD, gross lines and nullable breakdowns; required order shipping/tax with zero defaults |
| B-06 | Deletion/privacy-compatible ownership | Approved cart XOR and token uniqueness; Cart User FK RESTRICT; historical matrix preserved, service/audit policy remains future work |
| B-07 | Toolchain and migration scope | Compatible pinned versions, native/SQL feature strategy and complete baseline approval |

Later business policies, if approved storage suffices: exact key/guest-cart retention (48 hours/30 days still proposed), guest merge/caps, worker cadence, backoff, customer cancellation permissions, staff refund procedures, tax/rate providers, geography, rounding algorithm and reporting definitions. Decide these before their features ship. The 30-minute initial target is established; coordination and late-payment recovery mechanics are needed before checkout.

The owner resolved the baseline storage gates and authorized local generation. Future tax/shipping/privacy/provider changes that require different storage need a separately reviewed migration. No connection/application, 23rd entity or refund workflow is authorized.

For the current Part A handoff, consult foundation sections 4 and 7 for the actual remaining migration requirements. Concrete proposed enums, Decimal(12,2), scalar FKs/deletion matrix, accepted-payment composite membership and required reservation links have been implemented. Optional composite checkout owner/source FKs are not adopted; locked ownership checks remain mandatory future service work. Custom partial indexes/CHECKs are documented SQL, not deployed protections. The owner has now approved the four baseline decisions, including financial/address nullability, guest/cart constraints and catalog deferrals. Their old readiness blockers are closed.

## 13. Documentation and code alignment

Commerce /api/v1 is accepted by ADR-002; current /api and health/Swagger exceptions await an API task. Preserve working packages/types and packages/config. Existing ADR statuses are not automatically promoted. PRD/roadmap milestone numbering is editorial, not a schema blocker.

## 14. Technical references

- [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html): NULL checks, FK actions, cross-record limitations.
- [Prisma PostgreSQL features](https://www.prisma.io/docs/orm/contract-authoring/advanced-postgresql): verify against the selected major.
- [Stripe limited inventory](https://docs.stripe.com/payments/checkout/managing-limited-inventory.md?ui=full-page): provider/session expiry differs from a local reservation deadline.
- [Stripe webhooks](https://docs.stripe.com/webhooks): duplicate, delayed and out-of-order events.
