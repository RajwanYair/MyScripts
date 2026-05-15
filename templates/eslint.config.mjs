// =============================================================================
// ESLint flat config template for new TypeScript web projects.
// Extends the shared base from tooling/eslint/base.mjs.
// =============================================================================
import baseConfig from "../tooling/eslint/base.mjs";

export default [
  ...baseConfig,
  {
    // Project-specific overrides go here
    rules: {
      // No suppressions by default — address all findings
    },
  },
  {
    ignores: ["dist/", "coverage/", "node_modules/"],
  },
];
