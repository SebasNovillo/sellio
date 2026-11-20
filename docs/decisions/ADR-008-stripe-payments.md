# ADR-008: Stripe for Test-Mode Payments

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Use Stripe test mode for V1 checkout; confirm payments through verified, idempotent webhooks and reconcile uncertain states.

## Alternatives considered

Mock-only payments; another payment provider.

## Consequences and trade-offs

Realistic checkout integration; asynchronous events, refunds, taxes and inventory reservation expiry require careful design.

## Validation and revisit trigger

Choose Stripe integration mode and resolve tax/shipping policy before M5.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
