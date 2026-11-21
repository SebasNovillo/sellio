# Sellio

Sellio is a portfolio-quality electronics e-commerce platform demonstrating professional full-stack engineering. This initial scaffold contains two independent frontend applications and a shared REST API. Product catalog, authentication, cart, checkout, payments, and admin business features are intentionally reserved for later tasks.

## Stack

- Frontends: Next.js App Router, React, TypeScript, Tailwind CSS, ESLint.
- Backend: Node.js, NestJS, REST, OpenAPI / Swagger.
- Workspace: pnpm 10, Turborepo, shared TypeScript and ESLint configuration.
- Database foundation: PostgreSQL Prisma schema/client (22 models); migrations have not been applied. Planned integrations: Supabase Auth and Storage, Stripe test mode.
- CI: GitHub Actions runs installation, linting, TypeScript checks, and production builds.
- Offline database infrastructure tests use Node's built-in runner. Vitest or Jest for domain behavior and Playwright for browser flows remain planned; no business features are implemented.

## Structure

```text
apps/
  storefront/       # Next.js, port 3000
  admin/            # Next.js, port 3001
  api/              # NestJS, port 4000
packages/
  ui/               # One shared heading to verify frontend workspace imports
  types/            # Shared health-response contract
  config/           # Base, Next.js, and Node TypeScript configurations
  eslint-config/    # Shared flat ESLint configurations
docs/
  architecture/
  database/
  design/
  decisions/
.github/workflows/
```

## Prerequisites

- Node.js 22.22.3 is the pinned application runtime in `.nvmrc` and `pnpm-workspace.yaml`. pnpm downloads this runtime automatically and uses it for workspace scripts, so the inspected system Node.js 22.12 can bootstrap installation without a global upgrade.
- pnpm **10.34.9**, pinned by `packageManager`. pnpm 11 requires a newer Node.js baseline and is not the package manager for this repository.
- Git.
- No database, Supabase project, or Stripe account is needed to run the scaffold.

Install the pinned package manager with `npm install --global pnpm@10.34.9`, or use `npm exec --yes --package=pnpm@10.34.9 -- pnpm <command>` without changing your global installation. All commands below assume the pinned pnpm is active. The initial installation needs access to the npm registry and nodejs.org for the managed runtime.

## Installation

```sh
pnpm install
```

Frontend environment files remain optional. The API now requires a PostgreSQL DATABASE_URL to configure its lazy Prisma client; startup and the existing health endpoint do not query it. Prisma validation/generation and builds need no database URL or running database. To prepare local configuration in PowerShell:

```powershell
Copy-Item apps/storefront/.env.example apps/storefront/.env.local
Copy-Item apps/admin/.env.example apps/admin/.env.local
Copy-Item apps/api/.env.example apps/api/.env.local
```

Only copy files that do not already exist. Integration placeholders may remain empty. The API reads `.env.local` before `.env` in `apps/api`; shell variables take precedence. Only `NEXT_PUBLIC_` variables belong in frontend environment files. Secret environment files are ignored by Git; examples are tracked.

For Supabase development, set the API's `DATABASE_URL` to the shared transaction pooler and `DIRECT_URL` to the shared session pooler. Prisma CLI never falls back to the runtime URL. See [connection setup and approval boundaries](docs/database/SUPABASE_CONNECTIONS.md) before any connection or migration.

## Commands

Run commands from the repository root:

| Command | Purpose |
| --- | --- |
| `pnpm dev` | Start all three development servers, building required shared packages first |
| `pnpm dev:storefront` | Start storefront and its workspace dependencies |
| `pnpm dev:admin` | Start admin and its workspace dependencies |
| `pnpm dev:api` | Start API and its workspace dependencies |
| `pnpm lint` | Lint application and shared code |
| `pnpm typecheck` | Generate Next.js route types and check TypeScript across the workspace |
| `pnpm build` | Build shared packages and all applications |
| `pnpm --filter @sellio/api db:validate` | Validate the 22-model Prisma schema without connecting |
| `pnpm --filter @sellio/api db:generate` | Generate the API's local Prisma Client |
| `pnpm --filter @sellio/api test:database` | Compile and run offline infrastructure tests; TCP is prohibited |
| `pnpm --filter @sellio/storefront start` | Serve the built storefront |
| `pnpm --filter @sellio/admin start` | Serve the built admin |
| `pnpm --filter @sellio/api start` | Serve the built API |

Run `pnpm build` before production `start` commands. Stop development processes with Ctrl+C. The API compiles with TypeScript and restarts through Node's watch mode; frontend applications use Next.js hot reloading. If editing `packages/types`, rebuild it with `pnpm --filter @sellio/types build` to refresh generated declarations. `packages/ui` is transpiled directly by each frontend.

| Application | Local URL |
| --- | --- |
| Storefront | http://localhost:3000 |
| Admin | http://localhost:3001 |
| API health | http://localhost:4000/api/health |
| Swagger | http://localhost:4000/api/docs |
| OpenAPI JSON | http://localhost:4000/api/docs-json |

The health endpoint verifies the API process only. Swagger is enabled by default in development and disabled by default in production; `API_DOCS_ENABLED=true` explicitly enables it. `PORT` changes the API port; frontend ports are fixed in their scripts. Free the assigned ports before running all applications.

## Architecture and next steps

The frontends may share UI and contracts but do not depend on one another. Backend modules own business logic and privileged integrations. See [architecture](docs/architecture/README.md), [database](docs/database/README.md), [design](docs/design/README.md), and [initial decisions](docs/decisions/0001-monorepo-foundation.md).

Part A provides the Prisma foundation only. See [Prisma foundation and migration SQL](docs/database/PRISMA_FOUNDATION.md) for configuration, model/enum inventory, custom PostgreSQL constraints, provisional schema details and the next approval gate. Future tasks must review/generate/apply migrations to approved isolated PostgreSQL, configure Supabase and Stripe, and implement the domain services. CI runs offline schema/client tests and existing checks; it does not migrate a database. No commits, branches or remote deployment are created automatically.

Tooling notes: ESLint 9 is pinned for compatibility with the React lint plugin used by Next.js; npm marks this major as deprecated. pnpm may report the deliberately skipped `@scarf/scarf` install script, an optional telemetry script pulled in by Swagger. Neither warning prevents installation or verification.
