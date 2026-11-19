# 0001: Monorepo foundation

Status: Accepted

## Context

Sellio needs two independently deployable Next.js frontends and one NestJS API, with consistent tooling and explicit shared contracts.

## Decision

Use pnpm workspaces and Turborepo. Keep applications under `apps/`, shared code under `packages/`, and architectural documentation under `docs/`. Pin pnpm 10.34.9 to bootstrap from the inspected Node.js 22.12 environment. Let pnpm manage application Node.js 22.22.3 through `useNodeVersion`; current lint dependencies require at least Node.js 22.13. Use compatible stable framework versions and track the dependency lockfile for reproducible installation.

Share TypeScript and ESLint configuration, a compiled health-response contract, and one source-level React heading. Use native TypeScript compilation and Node watch mode for NestJS development, preserving decorator metadata without adding a generator CLI. Next.js transpiles the shared UI directly.

## Consequences

Turbo builds shared contracts before consumers. Each frontend maintains its own routing and configuration. Database, authentication, storage, payments, and testing frameworks will be introduced when their tasks require them, avoiding unused SDKs and speculative abstractions.
