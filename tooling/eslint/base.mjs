/**
 * Shared ESLint base configuration for vanilla JS (ES2025+) projects.
 * Source of truth — project-specific configs import and extend these exports.
 *
 * Usage in a project eslint.config.mjs:
 *   import { baseLinterOptions, baseLanguageOptions, baseRules, ... } from "../tooling/eslint/base.mjs";
 */

// ── Browser globals (shared across web projects) ──────────────────────────
export const browserGlobals = {
    window: "readonly",
    document: "readonly",
    navigator: "readonly",
    localStorage: "readonly",
    sessionStorage: "readonly",
    fetch: "readonly",
    Headers: "readonly",
    AbortController: "readonly",
    AbortSignal: "readonly",
    setTimeout: "readonly",
    clearTimeout: "readonly",
    setInterval: "readonly",
    clearInterval: "readonly",
    console: "readonly",
    requestAnimationFrame: "readonly",
    requestIdleCallback: "readonly",
    getComputedStyle: "readonly",
    Map: "readonly",
    Set: "readonly",
    Promise: "readonly",
    URLSearchParams: "readonly",
    URL: "readonly",
    Intl: "readonly",
    performance: "readonly",
    HTMLElement: "readonly",
    HTMLInputElement: "readonly",
    HTMLTextAreaElement: "readonly",
    HTMLFormElement: "readonly",
    HTMLSelectElement: "readonly",
    HTMLButtonElement: "readonly",
    HTMLAnchorElement: "readonly",
    HTMLImageElement: "readonly",
    HTMLCanvasElement: "readonly",
  OffscreenCanvas: "readonly",
  Image: "readonly",
    KeyboardEvent: "readonly",
    Event: "readonly",
    MouseEvent: "readonly",
    CustomEvent: "readonly",
    DOMParser: "readonly",
    location: "readonly",
    history: "readonly",
    Blob: "readonly",
    alert: "readonly",
    prompt: "readonly",
    confirm: "readonly",
    Notification: "readonly",
    CSS: "readonly",
    MutationObserver: "readonly",
    ResizeObserver: "readonly",
    IntersectionObserver: "readonly",
    FormData: "readonly",
    FileReader: "readonly",
    btoa: "readonly",
    atob: "readonly",
    structuredClone: "readonly",
    WebSocket: "readonly",
    crypto: "readonly",
    indexedDB: "readonly",
    IDBDatabase: "readonly",
    IDBRequest: "readonly",
    TextEncoder: "readonly",
    TextDecoder: "readonly",
};

// ── Node / script globals ─────────────────────────────────────────────────
export const nodeGlobals = {
    process: "readonly",
    __dirname: "readonly",
    __filename: "readonly",
    Buffer: "readonly",
};

// ── Linter options ────────────────────────────────────────────────────────
export const baseLinterOptions = {
    reportUnusedDisableDirectives: "error",
};

// ── Language options ──────────────────────────────────────────────────────
export const baseLanguageOptions = {
    ecmaVersion: 2025,
    sourceType: "module",
};

// ── Shared rules (quality + safety) ───────────────────────────────────────
export const baseRules = {
    "no-eval": "error",
    "no-implied-eval": "error",
    "no-new-func": "error",
    "no-undef": "error",
    "no-dupe-args": "error",
    "no-dupe-keys": "error",
    "no-duplicate-case": "error",
    "no-unreachable": "error",
    "use-isnan": "error",
    "valid-typeof": "error",
    "no-constant-condition": ["error", { checkLoops: false }],
    "no-redeclare": ["error", { builtinGlobals: false }],
    "no-empty": ["error", { allowEmptyCatch: true }],
    eqeqeq: ["error", "smart"],
    "no-var": "error",
    "prefer-const": "error",
    "prefer-template": "error",
    "object-shorthand": ["error", "always"],
    "no-console": ["warn", { allow: ["error", "warn"] }],
    "no-unused-vars": [
        "error",
        {
            varsIgnorePattern: "^_",
            argsIgnorePattern: "^_|^e$|^k$",
            caughtErrors: "all",
            caughtErrorsIgnorePattern: "^_",
        },
    ],
    "no-prototype-builtins": "error",
    "no-inner-declarations": "error",
    "no-throw-literal": "error",
    "no-self-compare": "error",
    "no-sequences": "error",
    "no-useless-concat": "error",
    "no-useless-return": "error",
    "no-lone-blocks": "error",
    "no-lonely-if": "error",
};

// ── Test-file globals (happy-dom / jsdom compatible) ──────────────────────
export const testDomGlobals = {
    HTMLSpanElement: "readonly",
    HTMLInputElement: "readonly",
    HTMLButtonElement: "readonly",
    HTMLDivElement: "readonly",
    HTMLFormElement: "readonly",
    HTMLSelectElement: "readonly",
    HTMLTextAreaElement: "readonly",
    HTMLImageElement: "readonly",
    HTMLAnchorElement: "readonly",
    HTMLLIElement: "readonly",
    HTMLUListElement: "readonly",
    HTMLOListElement: "readonly",
    HTMLTableElement: "readonly",
    HTMLTableRowElement: "readonly",
    HTMLTableCellElement: "readonly",
    HTMLParagraphElement: "readonly",
    HTMLHeadingElement: "readonly",
    TouchEvent: "readonly",
    Touch: "readonly",
    HashChangeEvent: "readonly",
    PopStateEvent: "readonly",
    StorageEvent: "readonly",
    MessageEvent: "readonly",
    CloseEvent: "readonly",
    ProgressEvent: "readonly",
    ErrorEvent: "readonly",
    FocusEvent: "readonly",
    InputEvent: "readonly",
    DragEvent: "readonly",
    WheelEvent: "readonly",
};
