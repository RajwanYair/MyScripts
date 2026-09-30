// =============================================================================
// ESLint flat config template for new TypeScript SPA projects.
// Consolidates reusable production patterns across TypeScript SPA projects.
//
// Plugins (7): @eslint/js, typescript-eslint, react-hooks, react-refresh,
//              jsx-a11y, regexp, no-only-tests (+ eslint-config-prettier)
// =============================================================================
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import jsxA11y from "eslint-plugin-jsx-a11y";
import regexp from "eslint-plugin-regexp";
import noOnlyTests from "eslint-plugin-no-only-tests";
import eslintConfigPrettier from "eslint-config-prettier";

export default tseslint.config(
  { ignores: ["dist/", "coverage/", "node_modules/", "*.config.*"] },
  {
    files: ["**/*.{ts,tsx}"],
    extends: [
      js.configs.recommended,
      ...tseslint.configs.recommended,
      jsxA11y.flatConfigs.recommended,
      regexp.configs["flat/recommended"],
    ],
    plugins: {
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-eval": "error",
      "no-implied-eval": "error",
      eqeqeq: ["error", "smart"],
      "no-var": "error",
    },
  },
  {
    files: ["tests/**/*.{ts,tsx}"],
    plugins: { "no-only-tests": noOnlyTests },
    rules: {
      "no-only-tests/no-only-tests": "error",
      "@typescript-eslint/no-unused-vars": "off",
    },
  },
  eslintConfigPrettier,
);
