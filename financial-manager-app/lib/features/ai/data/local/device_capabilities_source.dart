import 'package:flutter/services.dart';

import '../../domain/models/device_capabilities.dart';
import '../../../../core/platform/platform_info.dart';

/// Reads [DeviceCapabilities] from the platform.
abstract interface class DeviceCapabilitiesSource {
  /// Null where on-device models aren't supported (anything but Android) or
  /// the platform call fails.
  Future<DeviceCapabilities?> read();
}

/// The Android implementation (MainActivity's "financialmanager/device"
/// channel).
class PlatformDeviceCapabilitiesSource implements DeviceCapabilitiesSource {
  const PlatformDeviceCapabilitiesSource();

  static const _channel = MethodChannel('financialmanager/device');

  @override
  Future<DeviceCapabilities?> read() async {
    if (!isAndroidApp) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'capabilities',
      );
      return raw == null ? null : DeviceCapabilities.fromJson(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
