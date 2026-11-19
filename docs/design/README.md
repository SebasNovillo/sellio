# Design

Storefront and admin use independent Next.js App Router roots and Tailwind CSS stylesheets. Both consume one minimal shared heading from `@sellio/ui` to verify source imports.

There is no component library or product design system yet. Introduce reusable components only when assigned screens demonstrate a shared need. Product screens and admin business UI are outside the initial scaffold.
