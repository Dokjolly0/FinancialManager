import 'local_model_catalog.dart';

/// What the phone offers to an on-device model. Fields are null when the
/// platform can't tell.
class DeviceCapabilities {
  const DeviceCapabilities({
    this.totalMemBytes,
    this.availMemBytes,
    this.lowMemory = false,
    this.freeStorageBytes,
    this.thermalStatus,
    this.batteryPercent,
    this.charging,
    this.socManufacturer,
    this.socModel,
    this.sdkInt,
  });

  final int? totalMemBytes;
  final int? availMemBytes;
  final bool lowMemory;
  final int? freeStorageBytes;

  /// Android PowerManager thermal status: 0 none … 6 shutdown.
  final int? thermalStatus;
  final int? batteryPercent;
  final bool? charging;
  final String? socManufacturer;
  final String? socModel;
  final int? sdkInt;

  /// MODERATE (2) or worse: runs are slower and the user is warned.
  bool get isWarm => (thermalStatus ?? 0) >= 2;

  /// SEVERE (3) or worse: runs are refused.
  bool get isHot => (thermalStatus ?? 0) >= 3;

  static DeviceCapabilities fromJson(Map<String, dynamic> json) =>
      DeviceCapabilities(
        totalMemBytes: json['total_mem'] as int?,
        availMemBytes: json['avail_mem'] as int?,
        lowMemory: json['low_memory'] as bool? ?? false,
        freeStorageBytes: json['free_storage'] as int?,
        thermalStatus: json['thermal_status'] as int?,
        batteryPercent: json['battery_pct'] as int?,
        charging: json['charging'] as bool?,
        socManufacturer: json['soc_manufacturer'] as String?,
        socModel: json['soc_model'] as String?,
        sdkInt: json['sdk'] as int?,
      );
}

/// Whether a model fits the phone's memory.
enum RamFit { fits, tight, insufficient, unknown }

const _mib = 1024 * 1024;

/// Fit of a catalog model at its default context, from the RAM measured in
/// the prototype. Phones report a little less than their nominal RAM (an
/// S26 Ultra with 12 GB reports 11.6), hence MiB thresholds below nominal.
RamFit ramFitForSpec(LocalModelSpec spec, int? totalMemBytes) {
  if (totalMemBytes == null) return RamFit.unknown;
  if (totalMemBytes >= spec.ramRecommendedMb * _mib) return RamFit.fits;
  if (totalMemBytes >= spec.ramMinMb * _mib) return RamFit.tight;
  return RamFit.insufficient;
}

/// Memory the KV cache and buffers take per context token, for files with
/// no measurement (imports). Deliberately on the high side.
const genericBytesPerContextToken = 256 * 1024;

/// Fit of a file with no catalog entry: the file, its context and 400 MB of
/// runtime must stay within half of the RAM to fit, within 70% to be tight.
RamFit estimateRamFit({
  required int fileBytes,
  required int contextTokens,
  required int? totalMemBytes,
}) {
  if (totalMemBytes == null) return RamFit.unknown;
  final need =
      fileBytes + contextTokens * genericBytesPerContextToken + 400 * _mib;
  if (need <= totalMemBytes * 0.5) return RamFit.fits;
  if (need <= totalMemBytes * 0.7) return RamFit.tight;
  return RamFit.insufficient;
}
