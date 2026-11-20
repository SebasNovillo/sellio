# ADR-009: Single-Store Initial Deployment

- **Status:** Accepted
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Deploy one independently configured store per installation; do not implement multi-tenant isolation in V1.

## Alternatives considered

Multi-tenant SaaS from launch.

## Consequences and trade-offs

Lower scope and security complexity; later SaaS migration will require data and authorization redesign.

## Validation and revisit trigger

Revisit only after a concrete multi-store business requirement.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
