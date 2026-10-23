import { TestBed } from '@angular/core/testing';

import { REFRESH_TOKEN_KEY, RefreshNetworkError, TokenStore } from './token-store';

/** A fake /auth/refresh that rotates tokens and rejects any replayed one, like the backend. */
function rotatingServer() {
  let current = 'r1';
  let issued = 1;
  const calls: string[] = [];
  const fetchMock = vi.fn(async (_url: string, init: RequestInit) => {
    const { refresh_token } = JSON.parse(init.body as string) as { refresh_token: string };
    calls.push(refresh_token);
    await new Promise((resolve) => setTimeout(resolve, 5));
    if (refresh_token !== current) return new Response('{}', { status: 401 });
    issued++;
    current = `r${issued}`;
    return Response.json({ access_token: `a${issued}`, refresh_token: current });
  });
  return { fetchMock, calls };
}

/** navigator.locks for jsdom: runs the tasks of one lock name one after the other. */
function serialLocks() {
  const queues = new Map<string, Promise<unknown>>();
  return {
    request: (name: string, task: () => Promise<unknown>) => {
      const previous = queues.get(name) ?? Promise.resolve();
      const run = previous.then(task, task);
      queues.set(
        name,
        run.catch(() => undefined),
      );
      return run;
    },
  };
}

describe('TokenStore', () => {
  beforeEach(() => {
    localStorage.clear();
    Object.defineProperty(navigator, 'locks', { value: serialLocks(), configurable: true });
  });

  afterEach(() => vi.unstubAllGlobals());

  it('stores the refresh token and keeps the access token in memory', () => {
    const store = TestBed.inject(TokenStore);
    store.applyTokens({ access_token: 'a1', refresh_token: 'r1' });
    expect(store.accessToken).toBe('a1');
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBe('r1');
    expect(store.hasStoredSession()).toBe(true);
    store.clear();
    expect(store.accessToken).toBeNull();
    expect(store.hasStoredSession()).toBe(false);
  });

  it('shares one refresh between concurrent callers', async () => {
    const server = rotatingServer();
    vi.stubGlobal('fetch', server.fetchMock);
    localStorage.setItem(REFRESH_TOKEN_KEY, 'r1');
    const store = TestBed.inject(TokenStore);

    const tokens = await Promise.all([store.refresh(), store.refresh(), store.refresh()]);

    expect(tokens).toEqual(['a2', 'a2', 'a2']);
    expect(server.calls).toEqual(['r1']);
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBe('r2');
  });

  it('never replays a rotated token across tabs', async () => {
    const server = rotatingServer();
    vi.stubGlobal('fetch', server.fetchMock);
    localStorage.setItem(REFRESH_TOKEN_KEY, 'r1');
    // Two tabs: two stores sharing localStorage and the lock.
    const tabA = new TokenStore();
    const tabB = new TokenStore();

    const [a, b] = await Promise.all([tabA.refresh(), tabB.refresh()]);

    expect(server.calls).toEqual(['r1', 'r2']);
    expect([a, b]).toEqual(['a2', 'a3']);
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBe('r3');
  });

  it('returns null when the server rejects the refresh token', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response('{}', { status: 401 })),
    );
    localStorage.setItem(REFRESH_TOKEN_KEY, 'stale');
    expect(await TestBed.inject(TokenStore).refresh()).toBeNull();
  });

  it('keeps the session on network errors', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new TypeError('Failed to fetch');
      }),
    );
    localStorage.setItem(REFRESH_TOKEN_KEY, 'r1');
    const store = TestBed.inject(TokenStore);
    await expect(store.refresh()).rejects.toBeInstanceOf(RefreshNetworkError);
    expect(store.hasStoredSession()).toBe(true);
  });

  it('reports expiry when another tab signs out', () => {
    const store = TestBed.inject(TokenStore);
    store.applyTokens({ access_token: 'a1', refresh_token: 'r1' });
    const expired = vi.fn();
    store.expired.subscribe(expired);

    window.dispatchEvent(new StorageEvent('storage', { key: REFRESH_TOKEN_KEY, newValue: null }));

    expect(expired).toHaveBeenCalledOnce();
    expect(store.accessToken).toBeNull();
  });
});
