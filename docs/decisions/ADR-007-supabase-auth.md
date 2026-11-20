# ADR-007: Supabase Auth for Identity

- **Status:** Proposed
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Use Supabase Auth for identity and sessions; the API verifies tokens and authorizes actions using server-managed roles in application data.

## Alternatives considered

Custom JWT/password system; Auth.js; another managed identity provider.

## Consequences and trade-offs

Less custom credential handling; must validate issuer/audience/JWKS and define account lifecycle and bootstrap-admin procedures.

## Validation and revisit trigger

Review token validation, role assignment and local testing during M2.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
