# Architecture

- `apps/storefront` is the customer-facing Next.js application.
- `apps/admin` is an independent Next.js application for future administrative workflows.
- `apps/api` is the shared NestJS REST backend. Domain modules will be introduced here when assigned.
- Frontends communicate with the backend through its REST API. Business rules and privileged integration credentials belong in the API.
- `packages/types` publishes compiled TypeScript contracts. Its initial contract is consumed by the API and checked in each frontend.
- `packages/ui` contains only a shared heading, consumed by both frontends to verify workspace imports. It is transpiled by Next.js without a separate bundle.
- `packages/config` and `packages/eslint-config` centralize tooling conventions.

The initial `/api/health` endpoint and optional Swagger document are infrastructure only. There are no domain endpoints, authentication, database connections, or payment flows yet. CORS policy will be configured alongside actual frontend API calls.
