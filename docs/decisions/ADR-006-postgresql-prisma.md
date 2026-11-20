# ADR-006: PostgreSQL and Prisma

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Store transactional commerce data in PostgreSQL; use Prisma for schema and data access, with SQL constraints and transactions where needed.

## Alternatives considered

MongoDB; Drizzle; direct SQL.

## Consequences and trade-offs

Relational integrity and migrations; some complex concurrency and database constraints require explicit SQL review.

## Validation and revisit trigger

Resolve database design open decisions before the first migration.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
