import type { Page, Route } from '@playwright/test';

/**
 * A tiny in-memory backend for the smoke tests: just enough of /api/v1 for
 * login, home, a new operation, history and reports. Anything else answers
 * 404, which the tests then see as an error.
 */
export async function mockApi(page: Page): Promise<{ created: unknown[] }> {
  const created: unknown[] = [];
  const now = new Date().toISOString();
  const wallet = {
    id: 'w1',
    name: 'Conto',
    type: 'BANK',
    icon: 'bank',
    color: '#176B5B',
    current_balance_minor: 125050,
    currency: 'EUR',
    version: 1,
    updated_at: now,
  };
  const transactions = [
    {
      id: 't1',
      wallet_id: 'w1',
      direction: 'DEBIT',
      kind: 'STANDARD',
      amount_minor: 2390,
      currency: 'EUR',
      title: 'Spesa',
      category_id: 'c1',
      occurred_at: now,
      created_at: now,
      updated_at: now,
      version: 1,
    },
  ];
  const profile = {
    id: 'u1',
    first_name: 'Mario',
    last_name: 'Rossi',
    username: 'mario',
    email: 'mario@example.com',
    email_verified: true,
    avatar_mode: 'generated',
    avatar_background_color: '#176B5B',
    avatar_text_color: '#FFFFFF',
    locale: 'it-IT',
    timezone: 'Europe/Rome',
    theme: 'light',
    balance_hidden_default: false,
    first_day_of_week: 'monday',
    ai_enabled: true,
    version: 1,
    created_at: now,
  };

  await page.route('**/api/v1/**', async (route: Route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname.replace('/api/v1', '');
    const json = (body: unknown, status = 200) =>
      route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
    const method = request.method();

    if (path === '/auth/login') {
      const body = request.postDataJSON();
      return body.password === 'password123'
        ? json({ access_token: 'access', refresh_token: 'refresh' })
        : json({ error: { code: 'INVALID_CREDENTIALS', message: 'no' } }, 401);
    }
    if (path === '/auth/refresh') return json({ access_token: 'access', refresh_token: 'refresh' });
    if (path === '/me') return json(profile);
    if (path === '/wallets') return json({ wallets: [wallet] });
    if (path === '/categories') {
      return json({
        categories: [
          {
            id: 'c1',
            name: 'Alimentari',
            direction_scope: 'DEBIT',
            is_system: true,
            sort_order: 1,
          },
        ],
      });
    }
    if (path === '/transaction-templates') return json({ templates: [] });
    if (path === '/transactions' && method === 'GET') {
      const title = new URL(request.url()).searchParams.get('title');
      const rows = title
        ? transactions.filter((t) => t.title.toLowerCase().includes(title.toLowerCase()))
        : transactions;
      return json({ transactions: rows, next_cursor: null, has_more: false });
    }
    if (path === '/transactions' && method === 'POST') {
      const body = request.postDataJSON();
      created.push(body);
      const row = {
        ...body,
        id: `t${transactions.length + 1}`,
        kind: 'STANDARD',
        created_at: now,
        updated_at: now,
        version: 1,
      };
      transactions.unshift(row);
      wallet.current_balance_minor +=
        body.direction === 'CREDIT' ? body.amount_minor : -body.amount_minor;
      return json({ transaction: row, wallet }, 201);
    }
    if (path === '/reports/summary') {
      return json({
        opening_balance_minor: 100000,
        closing_balance_minor: wallet.current_balance_minor,
        total_credits_minor: 50000,
        total_debits_minor: 24950,
        net_minor: 25050,
        transaction_count: transactions.length,
        currency: 'EUR',
        to: now,
      });
    }
    if (path === '/reports/timeseries') {
      return json({
        granularity: 'day',
        points: [
          {
            period_start: now,
            credits_minor: 50000,
            debits_minor: 24950,
            net_minor: 25050,
            balance_minor: wallet.current_balance_minor,
          },
        ],
      });
    }
    if (path === '/reports/breakdown') {
      return json({
        group_by: 'category',
        debits: [
          {
            key: 'c1',
            label: 'Alimentari',
            amount_minor: 24950,
            percentage: 100,
            transaction_count: 1,
          },
        ],
        credits: [],
      });
    }
    if (path === '/reports/monthly-comparison')
      return json({ months: [], spans_multiple_months: false });
    return json({ error: { code: 'NOT_FOUND', message: `mock: ${method} ${path}` } }, 404);
  });
  return { created };
}
