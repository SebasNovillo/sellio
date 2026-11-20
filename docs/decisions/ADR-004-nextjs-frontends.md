# ADR-004: Next.js for Storefront and Admin

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Build the storefront and admin as separate Next.js TypeScript applications, with Tailwind CSS and a limited shared UI package.

## Alternatives considered

Vite React SPAs; one combined Next.js application.

## Consequences and trade-offs

SEO-friendly public catalog and independent admin releases; additional deployment and auth integration complexity.

## Validation and revisit trigger

Validate hosting, caching, and session strategy during M1–M2.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
