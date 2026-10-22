import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../platform/platform_info.dart';

/// A human-readable device label + platform name to send with
/// login/register/Google-auth requests, so the backend's "Active
/// sessions" list (plan.md section 7.13) can show something more useful
/// than "Unknown device". Best-effort only — a failure here must never
/// block authentication.
class DeviceInfoService {
  Future<({String? deviceName, String? platform})> current() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        // "Chrome (Windows)": the browser and the OS it reports.
        final info = await plugin.webBrowserInfo;
        final browser = switch (info.browserName) {
          BrowserName.chrome => 'Chrome',
          BrowserName.edge => 'Edge',
          BrowserName.firefox => 'Firefox',
          BrowserName.safari => 'Safari',
          BrowserName.opera => 'Opera',
          BrowserName.samsungInternet => 'Samsung Internet',
          BrowserName.msie => 'Internet Explorer',
          BrowserName.unknown => 'Browser',
        };
        final os = (info.platform ?? '').trim();
        return (
          deviceName: os.isEmpty ? browser : '$browser ($os)',
          platform: 'web',
        );
      }
      if (isAndroidApp) {
        final info = await plugin.androidInfo;
        final name = '${info.manufacturer} ${info.model}'.trim();
        return (deviceName: name.isEmpty ? null : name, platform: 'Android');
      }
      if (isIosApp) {
        final info = await plugin.iosInfo;
        final name = info.name.trim().isNotEmpty
            ? info.name.trim()
            : info.modelName;
        return (deviceName: name.isEmpty ? null : name, platform: 'iOS');
      }
    } catch (_) {
      // Fall through to the platform-only fallback below.
    }
    return (
      deviceName: null,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
    );
  }
}
