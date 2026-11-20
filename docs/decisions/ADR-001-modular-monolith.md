# ADR-001: Modular Monolith

- **Status:** Accepted
- **Date:** 2026-11-17
- **Project:** Sellio V1
- **Related:** `docs/architecture/SYSTEM_ARCHITECTURE.md`, `docs/product/PRD.md`

## Context

Sellio is a reusable, initially single-store e-commerce platform with a customer storefront, administrative dashboard, and commerce backend. The project prioritizes a reliable test-mode purchase flow, maintainability, and future reuse without premature complexity.

## Decision

Deploy the commerce backend as one application with domain-oriented modules.

## Alternatives considered

Independent microservices; an unstructured monolith.

## Consequences and trade-offs

Simpler transactions, deployment and local development; module boundaries require discipline.

## Validation and revisit trigger

Revisit if independently scaling or deploying domains becomes necessary.

## Notes

A **Proposed** ADR records a preferred direction, not an approved or implemented choice. Changes require updating this record and affected architecture documentation. An **Accepted** ADR reflects agreement in planning, not proof of implementation.
