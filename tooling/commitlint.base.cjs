"use strict";
// Shared commitlint base configuration for MyScripts workspace projects.
// Extend in your project's commitlint.config.cjs:
//
//   module.exports = require('../tooling/commitlint.base.cjs');
//   // or to add project-specific scopes:
//   const base = require('../tooling/commitlint.base.cjs');
//   module.exports = { ...base, rules: { ...base.rules, 'scope-enum': [2, 'always', [...]] } };

/** @type {import('@commitlint/types').UserConfig} */
module.exports = {
    extends: ["@commitlint/config-conventional"],
    rules: {
        "type-enum": [
            2,
            "always",
            [
                "feat",
                "fix",
                "docs",
                "style",
                "refactor",
                "perf",
                "test",
                "chore",
                "ci",
                "revert",
            ],
        ],
        "subject-case": [
            2,
            "never",
            ["start-case", "pascal-case", "upper-case"],
        ],
        "header-max-length": [2, "always", 100],
        "body-max-line-length": [2, "always", 150],
        "footer-max-line-length": [2, "always", 150],
    },
};
