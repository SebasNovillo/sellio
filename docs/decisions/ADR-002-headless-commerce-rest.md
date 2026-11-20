# ADR-002: Headless Commerce with Versioned REST

- **Status:** Accepted
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Keep authoritative commerce logic in a backend API consumed by separate storefront and admin applications; version public contracts under /api/v1.

## Alternatives considered

Backend-for-frontend only; tightly coupled full-stack application; GraphQL-first.

## Consequences and trade-offs

Reusable for future clients; requires explicit contracts, authentication and network error handling.

## Validation and revisit trigger

Revisit API style if client requirements justify a different interface.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
