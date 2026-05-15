/**
 * ESLint preset for Node.js / Cloudflare Worker TypeScript projects.
 *
 * Extends the shared base rules but swaps browser globals for Node.js/Worker
 * globals so `process`, `Buffer`, `__dirname`, etc. are recognised.
 *
 * Usage (flat config):
 *   import { nodeAppConfig } from "../tooling/eslint/node-ts-app.mjs";
 *   export default [...nodeAppConfig({ tsconfigRootDir: import.meta.dirname })];
 */

import js from "@eslint/js";
import tseslint from "typescript-eslint";
import { sharedRules } from "./web-ts-app.mjs";

/** Globals available in a Node.js process / Cloudflare Worker environment. */
export const nodeGlobals = {
    // Node.js built-ins
    process: "readonly",
    Buffer: "readonly",
    __dirname: "readonly",
    __filename: "readonly",
    global: "readonly",
    globalThis: "readonly",
    // Timers (Node + Worker)
    setTimeout: "readonly",
    clearTimeout: "readonly",
    setInterval: "readonly",
    clearInterval: "readonly",
    // Promise / async
    Promise: "readonly",
    queueMicrotask: "readonly",
    // URL
    URL: "readonly",
    URLSearchParams: "readonly",
    // Fetch API (Node 18+ / Cloudflare Worker)
    fetch: "readonly",
    Request: "readonly",
    Response: "readonly",
    Headers: "readonly",
    FormData: "readonly",
    // Console
    console: "readonly",
    // Crypto
    crypto: "readonly",
    // Encoding
    TextEncoder: "readonly",
    TextDecoder: "readonly",
    // Structured clone
    structuredClone: "readonly",
    // Blob / File
    Blob: "readonly",
    File: "readonly",
    // Map / Set
    Map: "readonly",
    Set: "readonly",
    // Intl
    Intl: "readonly",
    // Performance
    performance: "readonly",
};

/**
 * Returns an ESLint flat config array for a Node.js / Worker TypeScript app.
 *
 * @param {{ tsconfigRootDir: string, files?: string[] }} opts
 */
export function nodeAppConfig({
    tsconfigRootDir,
    files = ["src/**/*.ts"],
} = {}) {
    return [
        js.configs.recommended,
        ...tseslint.configs.recommended,
        {
            files,
            languageOptions: {
                globals: nodeGlobals,
                parserOptions: {
                    project: true,
                    tsconfigRootDir,
                },
            },
            rules: {
                ...sharedRules,
                // No browser-only APIs in Node/Worker code
                "@typescript-eslint/no-explicit-any": "error",
                "@typescript-eslint/no-floating-promises": "error",
                "@typescript-eslint/no-misused-promises": "error",
                // Allow process.exit in Node scripts
                "no-process-exit": "off",
            },
        },
    ];
}
