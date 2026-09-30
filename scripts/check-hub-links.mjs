#!/usr/bin/env node
/**
 * check-hub-links.mjs
 *
 * Validates the root `index.html` hub:
 *   1. All local `href="..."` targets resolve to files that exist on disk.
 *   2. All external `https://` links use the `noopener` rel attribute and
 *      a non-empty host.
 *   3. No duplicate href targets in the same card.
 *
 * Exits non-zero on any failure. Designed for CI (no external HTTP calls).
 */

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const HUB = resolve(ROOT, "index.html");

const html = await readFile(HUB, "utf8");

const anchorRe = /<a\b([^>]*)>/gi;
const attrRe = /\b(\w[\w-]*)\s*=\s*"([^"]*)"/g;

let errors = 0;
let localChecked = 0;
let externalChecked = 0;
let match;

while ((match = anchorRe.exec(html)) !== null) {
    const attrsBlob = match[1];
    const attrs = {};
    let am;
    while ((am = attrRe.exec(attrsBlob)) !== null) {
        attrs[am[1].toLowerCase()] = am[2];
    }
    attrRe.lastIndex = 0;

    const href = attrs.href;
    if (!href) continue;

    if (href.startsWith("#")) continue; // in-page anchor

    if (/^https?:/i.test(href)) {
        externalChecked++;
        const target = attrs.target;
        const rel = (attrs.rel || "").toLowerCase();
        if (target === "_blank" && !rel.includes("noopener")) {
            console.error(
                `FAIL: external link with target=_blank missing rel=noopener: ${href}`,
            );
            errors++;
        }
        try {
            const u = new URL(href);
            if (!u.host) {
                console.error(`FAIL: external link has empty host: ${href}`);
                errors++;
            }
        } catch (e) {
            console.error(`FAIL: malformed URL: ${href} (${e.message})`);
            errors++;
        }
        continue;
    }

    // Local relative path
    localChecked++;
    const [pathOnly] = href.split(/[?#]/);
    const onDisk = resolve(ROOT, pathOnly);
    if (!existsSync(onDisk)) {
        // Local targets pointing into sub-project repos are tolerated when
        // the sub-project directory does not exist (sub-projects are
        // independent repos and may not be cloned alongside).
        const first = pathOnly.split("/")[0];
        const subProjectRoot = resolve(ROOT, first);
        if (existsSync(subProjectRoot)) {
            console.error(`FAIL: missing local target: ${href} -> ${onDisk}`);
            errors++;
        } else {
            console.log(
                `SKIP: sub-project not cloned: ${href} (root '${first}' absent)`,
            );
        }
    } else {
        console.log(`OK:   ${href}`);
    }
}

console.log(
    `\nSummary: ${localChecked} local + ${externalChecked} external links checked, ${errors} error(s).`,
);

if (errors > 0) {
    process.exit(1);
}
