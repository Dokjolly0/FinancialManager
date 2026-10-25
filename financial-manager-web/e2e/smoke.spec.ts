import { expect, test } from '@playwright/test';

import { mockApi } from './mock-api';

// Uncaught errors and CSP violations (logged by the init script) fail the test.
let problems: string[] = [];

test.beforeEach(async ({ page }) => {
  problems = [];
  page.on('pageerror', (error) => problems.push(String(error)));
  page.on('console', (message) => {
    if (message.text().startsWith('CSP violation')) problems.push(message.text());
  });
  await page.addInitScript(() =>
    document.addEventListener('securitypolicyviolation', (e) =>
      console.error(`CSP violation: ${e.violatedDirective} ${e.blockedURI}`),
    ),
  );
});

test.afterEach(() => {
  expect(problems).toEqual([]);
});

test('login, add an operation, find it in history, open reports', async ({ page, isMobile }) => {
  const api = await mockApi(page);

  await page.goto('/app/history');
  await expect(page).toHaveURL(/\/login\?from=/);

  await page.fill('#login-user', 'mario');
  await page.fill('#login-password', 'wrong-password');
  await page.click('button[type=submit]');
  await expect(page.getByRole('alert')).toBeVisible();

  await page.fill('#login-password', 'password123');
  await page.click('button[type=submit]');
  // Back where the sign-in was asked for.
  await expect(page).toHaveURL(/\/app\/history$/);

  await page.goto('/app/home');
  await expect(page.getByRole('heading', { name: 'Ciao, Mario' })).toBeVisible();
  await expect(page.getByText('1.250,50 €').first()).toBeVisible();

  await page.goto('/app/transactions/new');
  await page.fill('#tx-amount', '12,50');
  await page.fill('#tx-title', 'Pizza');
  await page.getByRole('button', { name: 'Salva operazione' }).click();
  await expect.poll(() => api.created.length).toBe(1);
  expect(api.created[0]).toMatchObject({
    amount_minor: 1250,
    direction: 'DEBIT',
    title: 'Pizza',
    wallet_id: 'w1',
  });
  // The form goes back to where it was opened from.
  await expect(page).toHaveURL(/\/app\/home$/);
  await expect(page.getByText('Pizza')).toBeVisible();

  await page.goto('/app/history?q=pizza');
  await expect(page.getByText('Pizza')).toBeVisible();
  await expect(page.getByText('Spesa', { exact: true })).toHaveCount(0);

  await page.goto('/app/reports');
  await expect(page.getByText('Alimentari')).toBeVisible();
  if (!isMobile) await expect(page.locator('[echarts] canvas')).toBeVisible();
});
