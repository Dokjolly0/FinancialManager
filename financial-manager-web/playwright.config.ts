import { defineConfig, devices } from '@playwright/test';

/**
 * Browser smoke tests (npm run e2e) against the production build, with the
 * API mocked in the browser (e2e/mock-api.ts): no backend needed, so they
 * run in CI. Build first (npm run build).
 */
export default defineConfig({
  testDir: 'e2e',
  fullyParallel: true,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 1 : 0,
  reporter: process.env['CI'] ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://127.0.0.1:4300',
    locale: 'it-IT',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
  webServer: {
    command: 'node e2e/serve.mjs dist/financial-manager-web/browser 4300',
    url: 'http://127.0.0.1:4300/',
    reuseExistingServer: !process.env['CI'],
  },
});
