# ADR-003: pnpm Workspaces and Turborepo

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Use a monorepo with apps/storefront, apps/admin, apps/api and shared packages; pnpm manages dependencies and Turborepo orchestrates tasks.

## Alternatives considered

Separate repositories; npm workspaces; Nx.

## Consequences and trade-offs

Shared tooling and atomic cross-app changes; CI caching and workspace boundaries need setup.

## Validation and revisit trigger

Confirm toolchain compatibility and CI strategy during M1.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
