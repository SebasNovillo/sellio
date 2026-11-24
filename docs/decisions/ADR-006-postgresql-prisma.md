# ADR-006: PostgreSQL and Prisma

- **Status:** Accepted — stack, Part A foundation and separately authorized initial development migration applied and verified
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** [System architecture](../architecture/Sellio_SYSTEM_ARCHITECTURE.md), [PRD](../architecture/Sellio_PRD.md)

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Store transactional commerce data in PostgreSQL; use Prisma for schema and data access, with SQL constraints and transactions where needed.

The owner authorized Part A on 2026-11-20. Stable Prisma CLI, client and PostgreSQL adapter are pinned to 7.10.1 with ESM generation. After separate connection/security reviews and explicit authorization, the unchanged initial migration was applied and verified in sellio-dev on 2026-11-23. The [foundation record](../database/PRISMA_FOUNDATION.md) documents implementation and custom SQL; the [deployment record](../database/initial-migration-verification.md) records the target, history/checksum, verified definitions and outstanding security work. Part A alone did not authorize deployment; the later authorization covered only the initial migration and its bookkeeping. Domain services, seed data and future database/security changes remain separate tasks requiring approval.

## Alternatives considered

MongoDB; Drizzle; direct SQL.

## Consequences and trade-offs

Relational integrity and migrations; some complex concurrency and database constraints require explicit SQL review.

## Validation and revisit trigger

Resolve database design open decisions before the first migration.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
