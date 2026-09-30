# React SPA Playbook

> **Reference implementation**: `WoodworkingShop/` v4.2.0
> **Last reviewed**: 2026-05-26
> Deep-dive companion to [WEB_APP_BEST_PRACTICES.md](WEB_APP_BEST_PRACTICES.md).
> This playbook covers every layer of a production React SPA as implemented in this workspace.

---

## Stack Decision Matrix

| Need         | Choice                            | Reason                                                                                                |
| ------------ | --------------------------------- | ----------------------------------------------------------------------------------------------------- |
| UI framework | React 19                          | PDF renderer + i18next deep integration; React Compiler closes reactivity gap                         |
| State        | Zustand 5                         | RTK = +15 KB + 40% boilerplate for identical semantics; slice pattern achieves same modularity        |
| CSS          | Tailwind CSS v4                   | JIT extraction; logical props built-in; v4 `@import "tailwindcss"` syntax — no `@tailwind` directives |
| Build        | Vite 8 (Rolldown)                 | Fastest dev+prod; CRA deprecated; Next.js SSR adds no value for client-only SPA                       |
| i18n         | i18next 26 + react-i18next        | RTL support; lazy loading; plural rules; context-aware translations                                   |
| Tests        | Vitest 4 + Playwright 1.60        | Same config as Vite; axe-core for a11y assertions in E2E                                              |
| PDF          | `@react-pdf/renderer`             | Off-main-thread rendering; server-independent                                                         |
| Workers      | Comlink + Vite `?worker`          | Type-safe Worker RPC without manual postMessage serialization                                         |
| Persistence  | `idb-keyval`                      | 1 KB IndexedDB wrapper; no extra abstractions                                                         |
| Typing       | TypeScript 6 `erasableSyntaxOnly` | Aligns with TC39 type-stripping; esbuild/oxc/Node --strip-types compatible                            |

**Do not add**: Supabase, Valibot, Zod, Redux, MobX, Recoil, Jotai, TanStack Query — these are not in the workspace production dependency set. Validate with `as const` patterns and home-grown schema functions.

---

## Project Structure

```text
src/
  main.tsx            App bootstrap + SW registration + i18n init
  App.tsx             Root component (no logic — layout only)
  env.d.ts            Vite env type declarations (import.meta.env)
  index.css           Global CSS — @import "tailwindcss" + @theme tokens

  engine/             Pure TypeScript — no React, no DOM, no side effects
    types.ts          Branded types, Result<T,E>, domain types
    dimensions.ts     Dimension calculation
    parts.ts          Part generation
    cut-optimizer.ts  MaxRects BSSF algorithm
    validation/       Validation rules (split by domain)
    assembly/         Assembly instruction generation
    export/           DXF, G-code, BOM generation (pure TS)
    index.ts          Public barrel (explicit exports only)

  store/
    cabinet-store.ts  Root store — composes slices
    slices/           One file per feature slice
      ui-slice.ts
      config-slice.ts
      pdf-slice.ts

  components/
    layout/           App shell: Header, Sidebar, Footer, Icons
    configurator/     User input panels
    preview/          SVG 6-view preview
    optimizer/        Cut sheet result display
    assembly/         Step-by-step build guide
    pdf/              PDF document components

  hooks/              Custom React hooks (useCamera, useHaptics, useFocusTrap…)
  utils/              Export helpers, storage, URL state, CRDT sync, etc.
  i18n/               en.json + he.json (+ ar, de, es, fr placeholder parity)
  services/           External service wrappers (Supabase BYO, community catalog)
  workers/            Web Workers (file.worker.ts?worker import)
    cut-optimizer.worker.ts
    bom-export.worker.ts

tests/
  helpers.ts          cfg() factory — builds domain config from defaults + overrides
  setup.ts            jsdom setup, vi.mock stubs
  assertions.ts       Custom matchers
  engine/             Unit tests for engine/ — pure TS, no React
  store/              Zustand store action tests
  hooks/              Hook tests (renderHook)
  utils/              Utility function tests
  bench/              Vitest benchmark tests
  e2e/                Playwright smoke + a11y
  __mocks__/          Module stubs (virtual:pwa-register, etc.)
```

---

## Engine Layer

The `src/engine/` directory is a strict boundary.

**Rules:**

- No `import … from 'react'`
- No `import … from '../store/…'`
- No DOM APIs (`document`, `window`, `navigator`)
- No side effects — every function is pure (same input → same output)
- Tested directly in `tests/engine/` — no React testing utilities needed

**Benefits:**

- Runs in Web Workers without modification
- Testable in CI without a browser
- Portable to CLI tools, Node scripts, WASM targets
- Independently benchmarkable

```ts
// ✅ Good engine function
export function computeWaste(parts: Part[], sheet: Sheet): number {
  const used = parts.reduce((sum, p) => sum + p.width * p.length, 0);
  return sheet.width * sheet.length - used;
}

// ❌ Bad — engine function with React dependency
import { useCallback } from 'react';  // NEVER in engine/
export function computeWaste(…) { … }
```

---

## Store Patterns (Zustand 5)

### Root Store Composes Slices

```ts
// store/cabinet-store.ts
import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createConfigSlice, type ConfigSlice } from "./slices/config-slice";
import { createUiSlice, type UiSlice } from "./slices/ui-slice";

type StoreState = ConfigSlice & UiSlice;

export const useCabinetStore = create<StoreState>()(
    persist(
        (set, get, api) => ({
            ...createConfigSlice(set, get, api),
            ...createUiSlice(set, get, api),
        }),
        { name: "cabinet-store", partialize: (s) => ({ config: s.config }) },
    ),
);
```

### Slice Pattern

```ts
// store/slices/ui-slice.ts
export type UiSlice = {
    sidebarOpen: boolean;
    toggleSidebar: () => void;
};

export const createUiSlice = (set: SetState<UiSlice>): UiSlice => ({
    sidebarOpen: true,
    toggleSidebar: () => set((s) => ({ ...s, sidebarOpen: !s.sidebarOpen })),
});
```

### Always Spread the Full Slice

```ts
// ✅ Correct — spread prevents accidental state wipe
set((s) => ({ ...s, config: { ...s.config, width } }));

// ❌ Wrong — only sets config, clears everything else
set({ config: { ...config, width } });
```

### Outside React (workers, tests)

```ts
// Direct state access without hook
useCabinetStore.getState().setConfig({ width: 800 });
```

---

## i18n Architecture

### File Structure

```text
src/i18n/
  en.json    ← primary source language
  he.json    ← secondary required (parity enforced in CI)
  ar.json    ← placeholder (copy en values until translated)
  de.json    ← placeholder
  es.json    ← placeholder
  fr.json    ← placeholder
  index.ts   ← i18next init with lazy language loading
```

### Parity Rule

Every `t('key')` call in any `.tsx` or `.ts` file must have a matching entry in **both** `en.json` and `he.json` committed in the **same PR**.

```ts
// scripts/i18n-coverage.js — run: npm run i18n:coverage
// Exits non-zero if any key is missing in he.json
```

### i18next Init Pattern

```ts
// src/i18n/index.ts
import i18n from "i18next";
import { initReactI18next } from "react-i18next";

i18n.use(initReactI18next).init({
    lng: "en",
    fallbackLng: "en",
    resources: { en: { translation: enJson }, he: { translation: heJson } },
    interpolation: { escapeValue: false },
});
```

---

## Testing Architecture

### Test Factory

```ts
// tests/helpers.ts — cfg() builds a valid config from defaults + overrides
import { DEFAULT_CONFIG } from "../src/engine/types";
export const cfg = (overrides: Partial<Config> = {}): Config => ({
    ...DEFAULT_CONFIG,
    ...overrides,
});
```

### it.each for Parametrized Tests

```ts
// ✅ Right — readable parametrized test table
it.each([
    [cfg({ width: 0 }), "width must be positive"],
    [cfg({ depth: -1 }), "depth must be positive"],
    [cfg({ height: 9999 }), "height exceeds maximum"],
])("rejects invalid config: %o", (config, expectedError) => {
    const result = validate(config);
    expect(result.ok).toBe(false);
    expect(result.error).toContain(expectedError);
});

// ❌ Wrong — one it() per case is noise
it("rejects zero width", () => {
    expect(validate(cfg({ width: 0 })).ok).toBe(false);
});
it("rejects negative depth", () => {
    expect(validate(cfg({ depth: -1 })).ok).toBe(false);
});
```

### Coverage Thresholds

```ts
// vitest.config.ts
coverage: {
  thresholds: { statements: 85, branches: 78, functions: 83, lines: 85 },
  include: ['src/engine/**', 'src/utils/**', 'src/store/**', 'src/hooks/**'],
  exclude: ['src/engine/types.ts', 'src/engine/index.ts'],
}
```

### Web Worker Testing

Never import workers directly in unit tests — use a synchronous fallback or test the underlying function directly.

```ts
// ✅ Test the algorithm, not the worker wrapper
import { optimizeParts } from '../../src/engine/cut-optimizer';
it('packs all parts', () => { … });

// ❌ Don't instantiate workers in unit tests
import Worker from '../../src/workers/cut-optimizer.worker?worker';
```

---

## Web Worker Pattern (Comlink)

```ts
// src/workers/cut-optimizer.worker.ts
import { expose } from "comlink";
import { optimizeParts } from "../engine/cut-optimizer";
expose({ optimizeParts });

// src/hooks/useCutOptimizer.ts
import { wrap } from "comlink";
import CutOptimizerWorker from "../workers/cut-optimizer.worker?worker";

export function useCutOptimizer() {
    const workerRef = useRef<Worker>();
    const apiRef = useRef<Remote<typeof import("../workers/cut-optimizer.worker")>>();
    useEffect(() => {
        workerRef.current = new CutOptimizerWorker();
        apiRef.current = wrap(workerRef.current);
        return () => workerRef.current?.terminate();
    }, []);
    return apiRef;
}
```

---

## PDF Rendering Pattern

```tsx
// Render PDF in a Web Worker to avoid blocking the main thread
import { pdf } from "@react-pdf/renderer";

// Called from a worker or async action — never on the render path
async function generatePdf(config: Config): Promise<Blob> {
    const doc = <CabinetPdfDocument config={config} />;
    return pdf(doc).toBlob();
}
```

---

## PWA Update Pattern

```ts
// main.tsx — user-consent SW update (never auto-activate)
import { registerSW } from "virtual:pwa-register";
const updateSW = registerSW({
    onNeedRefresh() {
        // Show "Update available" banner — user clicks to update
        useToastStore.getState().add({ type: "update", updateSW });
    },
    onOfflineReady() {
        // Optional: notify user app works offline
    },
});
```

**Never use** `skipWaiting: true` or `clientsClaim: true` — these cause active users to see a blank screen when the new SW takes over mid-session.

---

## TypeScript Type Patterns

### Branded Types for Domain Values

```ts
// src/engine/types.ts
declare const _mm: unique symbol;
export type Mm = number & { readonly [_mm]: true };
export const mm = (n: number): Mm => n as Mm;

// Usage — prevents mixing units accidentally
const width: Mm = mm(600);
```

### Result<T, E> for Recoverable Errors

```ts
export type Ok<T> = { ok: true; value: T };
export type Err<E> = { ok: false; error: E };
export type Result<T, E = string> = Ok<T> | Err<E>;

export const ok = <T>(value: T): Ok<T> => ({ ok: true, value });
export const err = <E>(error: E): Err<E> => ({ ok: false, error });
```

### `as const` Instead of `enum`

```ts
// ❌ Forbidden (erasableSyntaxOnly)
enum Status {
    Active = "active",
    Inactive = "inactive",
}

// ✅ Required pattern
const Status = { Active: "active", Inactive: "inactive" } as const;
type Status = (typeof Status)[keyof typeof Status];
```

---

## Vite Configuration

```ts
// vite.config.ts — production baseline
export default defineConfig({
    cacheDir: resolve(os.tmpdir(), "ProjectName", ".vite_cache"),
    base: "/RepoName/",
    plugins: [react(), tailwindcss(), VitePWA(pwaOptions)],
    build: {
        target: "es2022",
        chunkSizeWarningLimit: 1600,
        modulePreload: { polyfill: true }, // Safari < 16.4 compat
        rollupOptions: {
            output: {
                manualChunks: (id) => {
                    if (id.includes("@react-pdf/renderer")) return "pdf-renderer";
                    if (id.includes("/i18next")) return "i18n-vendor";
                    if (id.includes("/react-dom/") || id.includes("/react/") || id.includes("/zustand")) return "vendor";
                },
            },
        },
    },
    resolve: { alias: { "@": resolve(__dirname, "src") } },
    define: { __APP_VERSION__: JSON.stringify(version) },
});
```

---

## GitHub Pages Deployment

```yaml
# .github/workflows/pages.yml
name: Deploy
on:
    push:
        branches: [main]
permissions:
    contents: read
    pages: write
    id-token: write
jobs:
    deploy:
        environment: { name: github-pages, url: "${{ steps.deployment.outputs.page_url }}" }
        runs-on: ubuntu-latest
        steps:
            - uses: ./.github/actions/setup-node
            - run: npm run build
            - uses: actions/upload-pages-artifact@v3
              with: { path: dist }
            - uses: actions/deploy-pages@v4
              id: deployment
```

---

## Quality Gate Reference

| Script                  | What it checks                     | Exit 0 =           |
| ----------------------- | ---------------------------------- | ------------------ |
| `npm run typecheck`     | TypeScript across all 4 tsconfigs  | Zero TS errors     |
| `npm run lint`          | ESLint `--max-warnings 0`          | Zero lint warnings |
| `npm run lint:css`      | Stylelint on `src/**/*.css`        | Zero CSS warnings  |
| `npm run lint:md`       | Markdownlint on `*.md` + `docs/**` | Zero MD issues     |
| `npm run format:check`  | Prettier drift                     | Zero drift         |
| `npm run i18n:coverage` | en/he key parity                   | 100% parity        |
| `npm test`              | All unit tests pass                | All pass           |
| `npm run build`         | Clean Vite production build        | Zero warnings      |
| `npm run bundle:check`  | JS/CSS size ≤ budget               | Within budget      |
| `npm run bench:check`   | Benchmarks ≤ 5× baseline           | No regression      |
| `npm run test:e2e`      | Playwright smoke + a11y            | 100% pass          |
| `npm run dead:check`    | No dead files or exports           | Zero dead          |

Full gate order: `npm run check` → `npm run build` → `npm run bundle:check` → `npm run bench:check`

---

## Competitive Benchmark Learnings

Key practices harvested from top-tier browser-based productivity tools:

| Tool/Pattern          | Source                           | Harvest                                           |
| --------------------- | -------------------------------- | ------------------------------------------------- |
| Engine/UI separation  | Figma, Linear                    | Pure-TS engine layer — no React coupling          |
| Offline-first + PWA   | Notion, Linear                   | Workbox with explicit user consent to update      |
| Typed postMessage     | Figma                            | Comlink for Worker RPC instead of raw postMessage |
| Budget enforcement    | webpack-bundle-analyzer practice | `config/bundle-budget.json` + CI gate             |
| Zero-waivers contract | Linear, Stripe eng               | No eslint-disable, no @ts-ignore, fix root cause  |
| Parametrized tests    | Jest/Vitest community            | `it.each` tables, one expect block per concept    |
| RTL-first design      | WhatsApp Web, Google Docs        | Logical Tailwind properties from day one          |
| Semantic PR titles    | Conventional Commits, GitHub     | `pr-title.yml` workflow enforces format           |
| Composite actions     | GitHub Actions docs              | `.github/actions/setup-node/` DRY pattern         |
| SBOM generation       | CISA guidance                    | `scripts/sbom.js` attached to every release       |
