export const sharedVitestTestConfig = {
    environment: "happy-dom",
    globals: true,
    pool: "forks",
    maxForks: 4,
    testTimeout: 10000,
    hookTimeout: 10000,
};
