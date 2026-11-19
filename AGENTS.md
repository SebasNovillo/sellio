# Sellio development conventions

- Use TypeScript for application and shared source code.
- Prefer clear, maintainable code and small modules over speculative abstractions.
- Follow the established pnpm and Turborepo architecture: applications in `apps/`, shared packages in `packages/`.
- Keep storefront and admin independent. Neither application may import the other's source code.
- Keep business logic and privileged service integrations in the NestJS backend.
- Use kebab-case for filenames and directories, PascalCase for React components and classes, and camelCase for functions and variables. Follow Next.js reserved filenames.
- Write code, comments, and documentation in English.
- Avoid unnecessary dependencies. Add a dependency only when the assigned task requires it.
- Do not implement features outside the assigned task.
- Share contracts through `@sellio/types`, minimal reusable UI through `@sellio/ui`, TypeScript configuration through `@sellio/config`, and ESLint configuration through `@sellio/eslint-config`.
- Keep credentials out of code and Git. Update the relevant `.env.example` when introducing an environment variable.
- Run `pnpm lint`, `pnpm typecheck`, and `pnpm build` before handing off changes. Add meaningful tests when implementing behavior.
- Do not create branches or commits without explicit human approval. Never push unless explicitly requested.
