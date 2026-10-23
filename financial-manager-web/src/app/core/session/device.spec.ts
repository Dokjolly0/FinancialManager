import { describeBrowser } from './device';

describe('describeBrowser', () => {
  it('names browser and OS like the app on the web', () => {
    expect(
      describeBrowser(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36',
      ),
    ).toBe('Chrome (Windows)');
    expect(
      describeBrowser(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36 Edg/141.0',
      ),
    ).toBe('Edge (Windows)');
    expect(
      describeBrowser(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7; rv:144.0) Gecko/20100101 Firefox/144.0',
      ),
    ).toBe('Firefox (macOS)');
    expect(
      describeBrowser(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
      ),
    ).toBe('Safari (iOS)');
    expect(describeBrowser('curl/8')).toBe('Browser');
  });
});
