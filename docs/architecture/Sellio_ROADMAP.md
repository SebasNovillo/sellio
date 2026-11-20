# Sellio — Development Roadmap

**Version:** 0.1 (Draft)  
**Date:** 2026-11-17  
**Status:** Proposed; milestones are planning targets, not commitments  
**Product:** Sellio — reusable single-store commerce platform  
**Document owner:** Project team  
**Canonical repository path:** `docs/product/ROADMAP.md`

## 1. Purpose

This roadmap translates the Sellio PRD, system architecture, and preliminary database design into an incremental implementation plan. Sellio V1 comprises a consumer-electronics storefront, an administrative dashboard, and a reusable NestJS commerce API. The initial deployment supports **one store**, with modular boundaries that can support additional storefronts later; multi-tenancy is explicitly out of scope.

**Planning principles**

- Deliver vertical, testable slices rather than building every backend module before any UI.
- Keep the commerce API authoritative for pricing, permissions, stock, and order state.
- Keep each milestone independently demonstrable, with tests and documentation updated alongside code.
- Use Stripe **test mode** and synthetic customer/product data throughout development and public demonstrations.
- Treat scope changes and unresolved design choices as tracked decisions; do not silently turn proposals into implementation requirements.

## 2. V1 success criteria

Sellio V1 is ready for a public portfolio demonstration when a visitor can browse products, register or sign in, add variants to a cart, complete a Stripe test-mode checkout, and view an order; an authorized manager can maintain the catalog, inventory, and fulfillment state. The API must enforce permissions and invariants independently of the UI. A deployment, setup guide, seed data, and repeatable automated tests must be available.

**Out of scope for V1:** multi-tenant stores, subscriptions, marketplaces, mobile apps, AI recommendations, reviews, wishlists, multi-currency, multi-warehouse stock, and production live-payment launch. Coupons and advanced analytics remain deferred unless the PRD is revised.

## 3. Delivery overview

| ID | Milestone | Primary outcome | Key dependency | Exit evidence |
|---|---|---|---|---|
| M0 | Decision and design gate | Approved V1 boundaries and implementable data model | Existing draft documents | Decisions recorded; ERD reviewed |
| M1 | Repository foundation | Running monorepo, API, apps, CI, local infrastructure | M0 | All apps boot; CI green |
| M2 | Identity and access | Secure customer/admin access | M1 | Role and ownership tests pass |
| M3 | Catalog and inventory | Admin-managed purchasable variants | M2 | Public catalog and inventory invariants tested |
| M4 | Storefront and cart | Usable shopping journey up to checkout | M3 | Cart and product E2E flows pass |
| M5 | Checkout, payments, orders | Test-mode purchase from cart to confirmed order | M4 | Webhook, idempotency, concurrency tests pass |
| M6 | Administration and fulfillment | Operational admin dashboard and order workflow | M5 | Manager completes order lifecycle |
| M7 | Hardening and release | Deployed, documented portfolio-quality V1 | M6 | Release checklist approved |

**Ordering note:** UI/UX work begins in M0 and proceeds alongside M1–M4. M6 dashboard scaffolding can start earlier, but order metrics must come from real backend data, not hard-coded figures.

## 4. Detailed milestones

### M0 — Requirements, architecture, and design gate

**Objective:** Resolve decisions that could cause expensive schema or payment-flow rework.

**Work items**

- [ ] Review and align `PRD.md`, `SYSTEM_ARCHITECTURE.md`, and `DATABASE_DESIGN.md`.
- [ ] Finalize the ERD: PKs, FKs, cardinalities, variant-option join, nullable relationships, and delete policies.
- [ ] Specify stock reservation/expiration, checkout retry, cancellation, and refund policies.
- [ ] Decide tax and shipping approach for the **test-mode V1**; document geographic assumptions and exclusions.
- [ ] Decide whether anonymous carts are retained and how guest carts merge after sign-in; checkout remains authenticated initially.
- [ ] Confirm Prisma + PostgreSQL and Supabase Auth integration details, including trusted JWT validation and role provisioning.
- [ ] Record accepted/proposed ADRs and define API error conventions.
- [ ] Map storefront and admin information architecture; prepare initial Figma flows and UI tokens.

**Deliverables:** approved ERD, migration-ready schema specification, decision log/ADRs, screen inventory, updated PRD.

**Exit criteria:** no unresolved blocking ambiguity about prices, stock, payment confirmation, authentication, or order state transitions.

### M1 — Monorepo and engineering foundation

**Objective:** Establish repeatable local development and CI.

**Work items**

- [ ] Initialize pnpm workspaces and Turborepo.
- [ ] Scaffold `apps/storefront` and `apps/admin` (Next.js + TypeScript), and `apps/api` (NestJS).
- [ ] Add shared lint/TypeScript configs and an API contract strategy; do not share Prisma models directly with frontend apps.
- [ ] Configure PostgreSQL, Prisma migrations, environment templates, and local setup scripts.
- [ ] Add structured errors, input validation, health endpoint, API versioning, and OpenAPI generation.
- [ ] Add GitHub Actions for lint, typecheck, unit tests, and build; configure secret scanning/dependency updates as available.
- [ ] Create seed scripts for fictional electronics products and non-sensitive test users.

**Deliverables:** bootable monorepo, setup README, first migration, baseline CI pipeline.

**Exit criteria:** a new developer can clone, configure, migrate, seed, and run all apps from documented steps; CI passes.

### M2 — Identity, profiles, and authorization

**Objective:** Establish secure customer and staff access.

**Work items**

- [ ] Implement Supabase Auth registration, sign-in, sign-out, and password recovery in the storefront.
- [ ] Validate access tokens server-side using the configured issuer/audience and trusted keys.
- [ ] Implement local user profile synchronization and address management.
- [ ] Implement CUSTOMER, MANAGER, and ADMIN role checks in NestJS.
- [ ] Provision the first administrator through a controlled setup procedure; prohibit self-promotion.
- [ ] Protect admin routes and enforce ownership on customer-specific resources.

**Deliverables:** functional auth screens, profile endpoints, role guards, auth/permission tests.

**Exit criteria:** unauthorized requests are rejected; customers cannot read others' resources or invoke staff operations; admin provisioning is documented.

### M3 — Catalog, variants, and inventory

**Objective:** Support a real, manageable product catalog.

**Work items**

- [ ] Implement brands, hierarchical categories, products, images, and publication states.
- [ ] Implement product options/values and unique purchasable variant combinations with unique SKUs.
- [ ] Implement price fields using decimal-safe handling and a documented USD currency policy.
- [ ] Add public product/category/search/filter/sort endpoints with pagination.
- [ ] Add authorized admin CRUD for products, variants, and categories.
- [ ] Add stock balances, adjustment history, low-stock visibility, and atomic availability checks.
- [ ] Add image uploads to Supabase Storage with authorization and file validation.

**Deliverables:** public catalog API, admin product management, inventory APIs, realistic seeded catalog.

**Exit criteria:** draft/archived products are not purchasable; variant combinations and SKUs are unique; concurrent stock adjustments cannot violate invariants.

### M4 — Storefront experience and shopping cart

**Objective:** Deliver a polished shopping flow before payment.

**Work items**

- [ ] Implement responsive landing page, product listings, category navigation, and product detail pages.
- [ ] Build variant selectors, stock indicators, search, filters, sorting, and loading/empty/error states.
- [ ] Implement cart creation, add/update/remove operations, and authenticated cart persistence.
- [ ] Revalidate cart prices and stock from the API; never treat browser prices as authoritative.
- [ ] Implement customer account pages, address selection, and cart summary.
- [ ] Complete keyboard/accessibility and mobile usability checks for core flows.

**Deliverables:** browse-to-cart flow and account experience; Playwright tests.

**Exit criteria:** a user can find a product, select a variant, manage quantities, and see accurate server-calculated totals without proceeding to payment.

### M5 — Checkout, Stripe test payments, and orders

**Objective:** Complete the core transaction flow safely.

**Work items**

- [ ] Define explicit order, payment, and inventory-reservation state machines.
- [ ] Implement server-side quote validation, taxes/shipping integration or documented V1 test assumptions, and order snapshots.
- [ ] Reserve stock atomically for a bounded checkout window; release on timeout/failure and consume on successful confirmation.
- [ ] Create Stripe Checkout Sessions or PaymentIntents according to a recorded ADR; use test mode only.
- [ ] Verify webhook signatures, deduplicate events by provider event ID, and handle out-of-order/repeated delivery.
- [ ] Implement idempotency keys for checkout creation and payment-processing side effects.
- [ ] Expose customer order history/details and order confirmation based on backend state, not the redirect page.
- [ ] Test payment failure, abandoned checkout, retry, and concurrent last-unit purchase.

**Deliverables:** test-mode checkout, order lifecycle, payment event ledger, integration and E2E tests.

**Exit criteria:** a test purchase creates one correct order; replayed webhooks do not duplicate effects; no overselling occurs in tested concurrent scenarios; failed/expired payments release stock according to policy.

### M6 — Admin operations and fulfillment

**Objective:** Allow store staff to operate the commerce workflow.

**Work items**

- [ ] Implement dashboard summary from actual orders/revenue data with clear status definitions.
- [ ] Build order list/detail, filtering, and authorized fulfillment-state transitions.
- [ ] Implement customer lookup with least-privilege access.
- [ ] Display stock movements, low-stock alerts, and recent orders.
- [ ] Support cancellation and refund handling **only to the extent defined in the approved V1 policy**; do not imply full returns management without implementing it.
- [ ] Add audit events for sensitive staff actions where specified by the architecture.

**Deliverables:** working admin dashboard and order management, staff E2E tests.

**Exit criteria:** manager can fulfill a test order end to end; invalid state transitions and unauthorized actions are blocked.

### M7 — Security, reliability, deployment, and portfolio release

**Objective:** Publish a trustworthy demonstration and a maintainable codebase.

**Work items**

- [ ] Complete unit, integration, API, and Playwright smoke suites in CI.
- [ ] Review authorization, input validation, rate limits, secrets, CORS, upload safety, and webhook handling.
- [ ] Add basic observability: request correlation, structured logs, error reporting, and health checks.
- [ ] Prepare deployment environments, migration procedure, backups, and rollback notes.
- [ ] Publish storefront and restricted admin demo; use fictional data and Stripe test mode.
- [ ] Document setup, architecture, API, testing, screenshots, known limitations, and portfolio demo flow.
- [ ] Verify responsive behavior, accessibility, performance budgets, and critical error states.

**Deliverables:** deployed V1 demo, release notes, updated documentation, portfolio-ready README.

**Exit criteria:** release checklist completed; repeatable deploy and rollback documented; no known critical payment, permission, or stock defects.

## 5. Cross-cutting workstreams

| Workstream | Start | Continuous expectations |
|---|---|---|
| UI/UX in Figma | M0 | Screen states, responsive layouts, reusable design tokens |
| Documentation | M0 | Update PRD, architecture, database, API contracts, ADRs with changes |
| Testing | M1 | Unit tests for rules; integration for persistence; E2E for customer/staff journeys |
| Security | M1 | Server-side authz, secrets hygiene, validation, auditability |
| DevOps | M1 | CI first; deployment and monitoring expanded toward M7 |
| Data quality | M1 | Deterministic seeds, migrations, safe test fixtures |

## 6. Suggested GitHub planning model

- **Milestones:** `M0 — Design Gate` through `M7 — V1 Release`.
- **Issue types:** `feature`, `bug`, `chore`, `docs`, `test`, `security`.
- **Area labels:** `storefront`, `admin`, `api`, `database`, `infra`, `design`.
- **Priority labels:** `P0` (blocking), `P1` (required V1), `P2` (polish), `P3` (deferred).
- **Issue template:** context, user value, scope, acceptance criteria, dependencies, tests, and documentation changes.
- **Branch convention (proposed):** `feat/<issue>-<topic>`, `fix/<issue>-<topic>`, `docs/<topic>`.

**Example issue:** `Implement atomic inventory reservation` — acceptance criteria: one unit cannot be reserved by two concurrent checkouts; expired reservations are released; retries are idempotent; tests cover race conditions.

## 7. Definition of done (per issue)

An issue is done only when the implementation meets acceptance criteria, types/lint pass, relevant tests are added and green, authorization and failure paths are considered, API contracts/docs are updated when affected, and changes have been reviewed. A feature is not considered complete solely because its UI renders.

## 8. Dependencies and release risks

| Risk | Consequence | Mitigation / decision gate |
|---|---|---|
| Incomplete variant-option model | Invalid or duplicate SKUs | Finalize join constraints in M0 |
| Overselling during checkout | Broken orders and customer trust | Atomic reservation design and concurrency tests in M5 |
| Duplicate/out-of-order webhooks | Duplicate payment/order side effects | Unique event IDs, idempotent transitions, replay tests |
| Tax/shipping assumptions unclear | Incorrect checkout totals | Decide scope before M5; keep test-only assumptions explicit |
| Auth role misconfiguration | Unauthorized administration | Trusted token verification, backend guards, controlled admin bootstrap |
| Over-engineering reusable core | Delayed V1 | Single-store scope; modular monolith; no premature plugin or tenant framework |
| UI scope expansion | Missed milestones | Freeze V1 acceptance criteria; defer nice-to-have features |

## 9. Open decisions to resolve before implementation

1. **Payments:** Stripe Checkout Sessions versus custom PaymentIntents integration.
2. **Tax and shipping:** provider/configuration, supported regions, and test-mode assumptions.
3. **Inventory:** reservation duration, expiration worker, cancellation and refund stock policy.
4. **Data model:** final ERD, variant-option uniqueness strategy, money precision, and delete policies.
5. **Cart:** guest cart persistence and merge rules.
6. **Deployment:** hosting providers and environment separation.
7. **Admin:** exact manager permissions and whether audit logs are required in V1.

Track outcomes as ADRs or PRD updates. Do not resolve these by assumption in implementation prompts.

## 10. Recommended implementation sequence for Codex

Start with a small, reviewable issue from M1 after M0 is approved. Each Codex task should cite relevant documentation, request only one bounded change, require tests, and identify any design ambiguities before coding. Review diffs and approve Git commits manually; avoid bundling multiple unrelated milestones into one prompt.

**First coding task (after M0):** scaffold the pnpm/Turborepo workspace and three minimal applications with shared tooling, health endpoints, setup documentation, and CI checks. No checkout or payment integration should be attempted in the first task.

## 11. Document traceability

- `docs/product/PRD.md` — product scope and acceptance criteria.
- `docs/architecture/SYSTEM_ARCHITECTURE.md` — system boundaries and integration patterns.
- `docs/architecture/DATABASE_DESIGN.md` — conceptual data model and migration gate.
- `docs/decisions/` — accepted technical decisions (to be created next).
- `docs/api/OPENAPI.yaml` — API contract (generated/maintained during implementation).

**Next documentation deliverable:** initial Architecture Decision Records (ADRs). After the Markdown set is complete, export readable Word versions from the canonical Markdown sources.
