# ADR-005: NestJS Commerce API

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Implement the commerce backend in NestJS using domain modules, services, controllers and validation at API boundaries.

## Alternatives considered

Express; Fastify directly; Next.js route handlers.

## Consequences and trade-offs

Consistent architecture and dependency injection; additional framework learning and boilerplate.

## Validation and revisit trigger

Verify runtime versions, testing and maintainability before implementation.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
