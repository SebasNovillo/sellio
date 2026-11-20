# ADR-010: Durable CheckoutAttempt Entity

- **Status:** Accepted — entity and responsibility only; detailed schema remains proposed
- **Date:** 2026-11-19
- **Approval:** Project owner explicitly approved CheckoutAttempt as the 22nd entity after the database architecture review.
- **Related:** [Database design](../database/Sellio_DATABASE_DESIGN.md), [implementation specification](../database/DATABASE_IMPLEMENTATION_SPEC.md), [ERD](../database/ERD.md)

## Context

The PRD requires checkout retries and payment webhooks not to create duplicate orders or stock effects. A logical checkout submission must survive interruptions, uncertain provider responses and concurrent requests. A submission may exist before it creates an order, while an order may have multiple provider payment attempts.

## Decision

Add CheckoutAttempt as a separate, durable, customer-owned checkout submission record. It owns idempotency-key identity, stable request fingerprinting, cart association, lifecycle/recovery state and optional resulting-order association. Keep Payment responsible for provider payment attempts and financial outcomes. The baseline contains 22 entities.

Use durable records plus transactional guards to prevent duplicate cart conversion and to recover interrupted work. An idempotency key, fingerprint or unique index alone cannot establish price authority, ownership, stock availability or exactly-once external effects.

## Alternatives considered

- Keep checkout idempotency fields on Order: viable but conflates pre-order submission/recovery with commercial history.
- Put submission identity on Payment: conflates one logical checkout with multiple payment attempts.
- In-memory deduplication: not durable across restarts or multiple API processes.

## Consequences

Checkout lifecycle, cart conversion and provider payment lifecycle remain distinct. The detailed fields, status values, leases, uniqueness, FK actions, retention and reconciliation storage are proposals in the implementation specification. This approval does not authorize Prisma installation, schema creation, migrations, connections or business-feature implementation.

**2026-11-20 scope update:** a subsequent owner instruction separately authorized Part A installation/schema/client/infrastructure using consistent proposed contracts. [PRISMA_FOUNDATION.md](../database/PRISMA_FOUNDATION.md) records the result and remaining ambiguities. That authorization does not apply migrations, connect a database or implement checkout/payment services; the original entity-only approval is preserved as history.

## Validation gate

Approve the proposed persistence contract and relationship matrix before the initial migration. Future tests must cover replay/conflicting input, concurrent different keys for one cart, stale-worker recovery, interrupted provider operations and multiple payment attempts without duplicated inventory effects. Original accepted ADRs are preserved; other proposed ADRs are not promoted automatically.
