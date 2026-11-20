# Sellio — Product Requirements Document

**Version:** 0.1 (Draft)  
**Last updated:** 2026-11-19  
**Status:** Draft — pending review  
**Product type:** Headless e-commerce platform with a reference storefront  
**Initial deployment:** Single-store  
**Primary market:** United States (USD)

## 1. Executive summary

Sellio is a modular e-commerce platform comprising a customer-facing storefront, an administrative dashboard, and a reusable commerce API. Its first reference implementation is a fictional consumer-electronics store. The commerce engine must remain independent of electronics-specific assumptions so it can support other retail storefronts later.

Sellio V1 targets a complete, demonstrable purchase journey—from product administration through catalog discovery, cart, authenticated checkout, test payment, order creation, and administrative fulfillment—rather than a static shopping demo. The first release is not a multi-tenant SaaS platform.

## 2. Product objectives

1. Deliver a functioning online store with a polished, responsive shopping experience.
2. Support product and variant management, inventory, carts, checkout, payments, and orders.
3. Provide an admin dashboard for routine store operations.
4. Expose a documented REST API usable by multiple client applications.
5. Keep core business logic reusable and separated from storefront branding.
6. Demonstrate sound security, testing, and deployment practices.

### Non-goals for V1

- Multi-tenant store creation, merchant self-service onboarding, or billing merchants.
- Marketplace/multi-vendor fulfillment.
- Native mobile applications.
- AI recommendations, advanced marketing automation, and loyalty programs.
- Multi-currency, multi-language, multi-warehouse operations.
- A general-purpose ERP, accounting system, or supplier procurement suite.

## 3. Users and access

| Role | Primary needs | Access boundaries |
| --- | --- | --- |
| Guest | Browse and search products; maintain a temporary cart | No order checkout in V1; cannot access private account data |
| Customer | Manage profile and addresses; purchase products; see own orders | Own data and orders only |
| Manager | Maintain catalog, variants, stock, and fulfillment | Operational permissions only; no role administration |
| Admin | Manage store operations, staff roles, and configuration | Full authorized store access |

**Security requirement:** Server-side authorization is mandatory. Administrative roles are provisioned by authorized administrators or a controlled bootstrap process, never by public sign-up.

## 4. Scope: V1 functional requirements

Identifiers are stable references for implementation and acceptance tests. **P0** means required for V1; **P1** means desirable if schedule allows.

### 4.1 Catalog and discovery

| ID | Priority | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| CAT-01 | P0 | Public product catalog with pagination | Visitors can browse active products; draft/archived products are not public |
| CAT-02 | P0 | Product detail page | Displays images, description, current price, available options, and stock status |
| CAT-03 | P0 | Categories and subcategories | Visitors can browse by category; a product can belong to multiple categories |
| CAT-04 | P0 | Search, filtering, and sorting | Search by product name; filter by category/brand and relevant attributes; sort by price |
| CAT-05 | P0 | Product variants | Each sellable variant has unique SKU, price, option values, and stock |
| CAT-06 | P0 | Responsive presentation | Catalog and product pages work on mobile and desktop |
| CAT-07 | P1 | Featured collections | Homepage can highlight selected products or categories |

### 4.2 Identity and customer account

| ID | Priority | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| ACC-01 | P0 | Sign up, sign in, sign out, password recovery | Customer can complete each flow with verified identity provider integration |
| ACC-02 | P0 | Customer profile | Signed-in user can view and update permitted profile fields |
| ACC-03 | P0 | Saved shipping addresses | Customer can add, edit, and remove their own addresses |
| ACC-04 | P0 | Order history | Customer sees only orders belonging to their account |

### 4.3 Cart and checkout

| ID | Priority | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| CART-01 | P0 | Guest and signed-in carts | Add, update, and remove variant quantities; guest cart persists for a reasonable session |
| CART-02 | P0 | Server-side cart validation | Checkout recalculates prices and validates quantities and availability |
| CHK-01 | P0 | Authenticated checkout | User provides/chooses shipping address and sees an itemized order summary |
| CHK-02 | P0 | Shipping and tax calculation | Totals use server-calculated shipping and a configured tax solution; final amount shown before payment |
| CHK-03 | P0 | Test-mode card payment | Stripe test payment can succeed or fail without real charges |
| CHK-04 | P0 | Reliable checkout state | Repeated requests/webhooks do not duplicate orders or stock deductions |
| CHK-05 | P0 | Inventory reservation | Concurrent checkouts cannot oversell; abandoned reservations expire and release stock |

### 4.4 Orders and fulfillment

| ID | Priority | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| ORD-01 | P0 | Create order from validated checkout | Order stores immutable snapshots of purchased items, totals, and shipping address |
| ORD-02 | P0 | Payment lifecycle | Payment state is updated only after verified server-side provider events |
| ORD-03 | P0 | Customer order details | Customer can view itemized status and totals for own orders |
| ORD-04 | P0 | Admin fulfillment updates | Authorized staff can mark orders as processing, shipped, or delivered |
| ORD-05 | P0 | Failure and cancellation handling | Failed/expired payments release reservations; cancellation policy and stock behavior are explicit |
| ORD-06 | P1 | Transactional emails | Send confirmation and basic order-status emails |

### 4.5 Administration

| ID | Priority | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| ADM-01 | P0 | Secure admin access | Guests/customers cannot reach protected admin operations |
| ADM-02 | P0 | Product administration | Create/edit/archive products, categories, brands, images, and variants |
| ADM-03 | P0 | Inventory administration | View stock, adjust quantities, and record reasoned inventory movements |
| ADM-04 | P0 | Order administration | Search orders, inspect details, and update permitted fulfillment states |
| ADM-05 | P0 | Dashboard overview | Show order count, gross sales, recent orders, and low-stock items from real data |
| ADM-06 | P0 | Customer directory | Authorized staff can inspect customer/order summaries without exposing credentials |
| ADM-07 | P1 | Staff and permissions management UI | Admin can manage Manager access via a protected workflow |

## 5. Core business rules

- **Variant is the sellable unit.** Every product has at least one variant, including a default variant when no options exist.
- **Published default variant.** The current database target requires exactly one valid default variant for each published product; draft assembly may be incomplete. A unique index alone does not enforce existence.
- **Inventory belongs to variants.** Available quantity = on-hand quantity minus reserved quantity; available stock cannot become negative.
- **Cart is not a reservation.** Adding to cart does not guarantee price or availability.
- **Server owns prices and totals.** Client-submitted prices, discounts, and totals are never authoritative.
- **Order snapshots are historical.** Purchased name, SKU, option selection, unit price, taxes, shipping, and address remain unchanged by later catalog/profile edits.
- **Payment confirmation is server-driven.** A browser redirect alone cannot mark an order as paid.
- **Provider events are idempotent.** Duplicate/out-of-order webhooks must not cause duplicate fulfillment or inventory changes.
- **Durable checkout identity.** CheckoutAttempt is the approved 22nd entity for customer-owned submissions, stable-input idempotency and recovery. A checkout submission and a provider payment attempt are distinct; detailed persistence and cart-conversion policies remain proposed in the database specification.
- **Payment truth and reconciliation.** Actual provider success remains recorded even when fulfillment is blocked or another attempt settles. Persistent reconciliation is required; it does not authorize self-service refunds or an extra sale.
- **Order and payment statuses are separate.** Fulfillment is not automatically equivalent to payment success.
- **Archive instead of hard-delete.** Referenced catalog items remain available for historical records.
- **USD for V1.** The current database target uses decimal-based monetary values, never binary floating-point calculations. Exact bounds, rounding and financial snapshot shape remain database/checkout design decisions.
- **Customer isolation.** Customers cannot read or change another customer's orders, addresses, or cart.

## 6. User journeys

### Customer purchase

1. Guest opens storefront and explores products.
2. Guest selects a variant and adds it to cart.
3. Guest signs in or registers before checkout.
4. Customer reviews cart and shipping details.
5. Server recalculates totals and reserves available stock atomically.
6. Customer completes Stripe test checkout/payment.
7. Verified payment webhook finalizes payment/order state and inventory changes.
8. Customer views order confirmation and order history.

### Store administration

1. Admin signs in to protected dashboard.
2. Admin creates product, options, variants, pricing, and images.
3. Manager records inventory quantities/adjustments.
4. Active product appears in storefront.
5. Manager monitors orders and advances fulfillment state.
6. Dashboard reflects order and inventory changes.

## 7. Non-functional requirements

| Area | V1 expectation |
| --- | --- |
| Security | HTTPS; least-privilege authorization; secure secrets; input validation; safe webhook signature verification; no card details stored by Sellio |
| Reliability | Transactional stock updates; idempotent payment events; explicit retry/error handling |
| Performance | Paginated queries and indexed lookup paths; measure and tune key catalog/checkout routes before release |
| Accessibility | Keyboard-friendly flows, labeled forms, sufficient contrast, and meaningful error messages; aim for WCAG 2.2 AA |
| Responsive UX | Usable on mobile, tablet, and desktop |
| Observability | Structured server logs, request correlation, and payment/order error visibility without logging sensitive data |
| Maintainability | Typed API contracts, modular domain boundaries, migration history, linting, and automated tests |
| Documentation | Setup instructions, environment variable template, API docs, architecture notes, and deployment guide |
| Data handling | Minimize personal data, protect shipping/contact information, and establish retention/deletion rules before production use |

## 8. Product boundaries and proposed implementation

The implementation architecture is described in [Sellio_SYSTEM_ARCHITECTURE.md](Sellio_SYSTEM_ARCHITECTURE.md); the proposed 22-entity persistence contract is in [DATABASE_IMPLEMENTATION_SPEC.md](../database/DATABASE_IMPLEMENTATION_SPEC.md).

| Component | Proposed technology |
| --- | --- |
| Customer storefront | Next.js, React, TypeScript, Tailwind CSS |
| Admin dashboard | Next.js, React, TypeScript, Tailwind CSS |
| Commerce API | NestJS (Node.js), REST, OpenAPI |
| Data layer | PostgreSQL, Prisma |
| Authentication | Supabase Auth; API validates access tokens and roles |
| Product images | Supabase Storage |
| Payments | Stripe test mode for V1 |
| Repository | pnpm workspaces + Turborepo (proposed) |
| Design | Figma |
| Testing | Unit/integration/API tests + Playwright end-to-end |

**Architecture constraint:** Start with a single-store modular monolith. Commerce rules must not depend on electronics-specific fields or visual branding.

## 9. Milestones and release gates

| Milestone | Deliverable | Exit condition |
| --- | --- | --- |
| M1 — Planning | Approved PRD, architecture, ERD, initial ADRs | Open decisions documented; data constraints reviewed |
| M2 — Design | Storefront/admin flows and design system | Key mobile/desktop screens reviewed |
| M3 — Foundation | Monorepo, CI, auth, database migrations | Apps run locally; protected API route works |
| M4 — Catalog | Catalog, variants, categories, inventory | Admin creates sellable products; storefront lists them |
| M5 — Shopping | Customer account, cart, checkout UI | Cart and address flows pass E2E tests |
| M6 — Commerce | Orders, stock reservations, Stripe test payments | Success/failure/duplicate-webhook scenarios pass |
| M7 — Administration | Orders, fulfillment, operational dashboard | Staff can manage real test orders end-to-end |
| M8 — Release | Deployment, security review, docs, demo data | Public demo works without live payments or exposed secrets |

## 10. Definition of done for V1

V1 is complete when a tester can create and publish a product as an administrator, stock its variants, browse it as a customer, purchase it with a Stripe test card, see an accurate order history, and fulfill the order in the admin dashboard. Payment failures, duplicate webhooks, and competing purchases must not corrupt stock or order state. Core workflows must have automated coverage, and the deployed demo must be documented and safe for public viewing.

## 11. Deferred features / future roadmap

- Discount codes, promotions, and gift cards.
- Product reviews, wishlists, and product comparison.
- Returns, partial refunds, and advanced fulfillment/shipping integrations.
- Advanced analytics, abandoned-cart campaigns, and transactional marketing.
- Multiple inventory locations and more complex shipping/tax rules.
- Multi-language and multi-currency storefronts.
- Flutter mobile client consuming the Sellio API.
- Multi-store/multi-tenant SaaS only after explicit redesign and isolation review.

## 12. Open decisions requiring confirmation

1. **Storefront brand:** Name and visual identity for the fictional electronics store (distinct from Sellio platform).
2. **Shipping scope:** Domestic U.S. only for V1? Which shipping methods and rate rules?
3. **Tax solution:** Stripe Tax or another configured tax provider; determine test/demo behavior and any production compliance requirements.
4. **Payment integration:** Stripe Checkout (hosted) vs embedded Payment Element; choose before final checkout UX and API design.
5. **Cancellation/refunds:** Which cancellation states are supported in V1, and whether refunds are manual or integrated.
6. **Guest cart merge:** How guest items transfer to authenticated cart on sign-in.
7. **Admin role bootstrap:** Secure first-admin provisioning process.
8. **Analytics definitions:** Clarify gross sales, paid orders, refunded orders, and reporting time zone.
9. **Inventory reservation coordination:** Initial target is 30 minutes; provider alignment, cleanup scheduling and late/delayed payment recovery remain open. Persisted storage must be approved before migration, behavior before checkout.
10. **Notifications:** Decide whether order-confirmation email is P0 or P1 for the first public demo.

## 13. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Scope creep | Strict V1/P1/future separation and milestone exit criteria |
| Overselling | Atomic reservation and stock operations, concurrency tests |
| Duplicate payments/orders | Idempotency keys, webhook event deduplication, reconciliation |
| Authorization leaks | Server-side guards and customer ownership tests |
| Unreliable external integrations | Test mode, retries, observability, explicit failure states |
| Tight coupling to electronics store | Domain-neutral commerce models and separate storefront branding |
| Premature SaaS complexity | Single-store architecture; defer tenancy until a dedicated design phase |

## 14. Related documents (planned)

- [System architecture](Sellio_SYSTEM_ARCHITECTURE.md)
- [Database design](../database/Sellio_DATABASE_DESIGN.md)
- [Implementation specification](../database/DATABASE_IMPLEMENTATION_SPEC.md)
- [ERD](../database/ERD.md)
- [Roadmap](Sellio_ROADMAP.md)
- `docs/decisions/ADR-*.md`
- `docs/api/OPENAPI.yaml` (generated/maintained with API implementation)
- `docs/design/DESIGN_SYSTEM.md` (after Figma work)

---

**Review note:** This PRD is an initial, actionable specification based on current project decisions. Items labeled proposed or open are not yet approved implementation choices.
