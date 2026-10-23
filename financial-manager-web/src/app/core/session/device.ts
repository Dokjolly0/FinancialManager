/**
 * Device label sent with login, register and Google sign-in so "Active
 * sessions" (plan.md section 7.13) shows "Chrome (Windows)" instead of an
 * unknown device, as the app's DeviceInfoService does on the web.
 */
export function deviceInfo(userAgent: string = navigator.userAgent): {
  device_name: string;
  platform: 'web';
} {
  return { device_name: describeBrowser(userAgent), platform: 'web' };
}

export function describeBrowser(userAgent: string): string {
  const browser = /SamsungBrowser\//.test(userAgent)
    ? 'Samsung Internet'
    : /Edg(e|A|iOS)?\//.test(userAgent)
      ? 'Edge'
      : /OPR\/|Opera/.test(userAgent)
        ? 'Opera'
        : /Firefox\/|FxiOS\//.test(userAgent)
          ? 'Firefox'
          : /Chrome\/|CriOS\//.test(userAgent)
            ? 'Chrome'
            : /Safari\//.test(userAgent)
              ? 'Safari'
              : 'Browser';
  const os = /Windows/.test(userAgent)
    ? 'Windows'
    : /Android/.test(userAgent)
      ? 'Android'
      : /iPhone|iPad|iPod/.test(userAgent)
        ? 'iOS'
        : /Mac OS X|Macintosh/.test(userAgent)
          ? 'macOS'
          : /CrOS/.test(userAgent)
            ? 'ChromeOS'
            : /Linux/.test(userAgent)
              ? 'Linux'
              : '';
  return os ? `${browser} (${os})` : browser;
}
