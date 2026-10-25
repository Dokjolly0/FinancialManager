import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';

import { authInterceptor } from './auth.interceptor';
import { TokenStore } from './token-store';

describe('authInterceptor', () => {
  let http: HttpClient;
  let backend: HttpTestingController;
  let tokens: TokenStore;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    backend = TestBed.inject(HttpTestingController);
    tokens = TestBed.inject(TokenStore);
    tokens.applyTokens({ access_token: 'old', refresh_token: 'r1' });
  });

  afterEach(() => backend.verify());

  const unauthorized = { error: { code: 'UNAUTHORIZED', message: 'x' } };

  it('sends the access token to the API only', () => {
    void firstValueFrom(http.get('/api/v1/me'));
    expect(backend.expectOne('/api/v1/me').request.headers.get('Authorization')).toBe('Bearer old');
    void firstValueFrom(http.get('i18n/it.json'));
    expect(backend.expectOne('i18n/it.json').request.headers.has('Authorization')).toBe(false);
  });

  it('refreshes once on an expired token and retries', async () => {
    vi.spyOn(tokens, 'refresh').mockResolvedValue('new');
    const result = firstValueFrom(http.get('/api/v1/me'));

    backend
      .expectOne('/api/v1/me')
      .flush(unauthorized, { status: 401, statusText: 'Unauthorized' });
    await Promise.resolve();
    const retry = backend.expectOne('/api/v1/me');
    expect(retry.request.headers.get('Authorization')).toBe('Bearer new');
    retry.flush({ id: 'u1' });

    expect(await result).toEqual({ id: 'u1' });
    expect(tokens.refresh).toHaveBeenCalledOnce();
  });

  it('ends the session when the refresh is rejected', async () => {
    vi.spyOn(tokens, 'refresh').mockResolvedValue(null);
    const expired = vi.fn();
    tokens.expired.subscribe(expired);
    const result = firstValueFrom(http.get('/api/v1/me'));

    backend
      .expectOne('/api/v1/me')
      .flush(unauthorized, { status: 401, statusText: 'Unauthorized' });

    await expect(result).rejects.toMatchObject({ status: 401 });
    expect(expired).toHaveBeenCalledOnce();
    expect(tokens.hasStoredSession()).toBe(false);
  });

  it('does not refresh on a 401 with a domain code', async () => {
    const refresh = vi.spyOn(tokens, 'refresh');
    const result = firstValueFrom(http.post('/api/v1/auth/password/change', {}));

    backend
      .expectOne('/api/v1/auth/password/change')
      .flush(
        { error: { code: 'INVALID_CURRENT_PASSWORD', message: 'x' } },
        { status: 401, statusText: 'Unauthorized' },
      );

    await expect(result).rejects.toMatchObject({ status: 401 });
    expect(refresh).not.toHaveBeenCalled();
  });
});
