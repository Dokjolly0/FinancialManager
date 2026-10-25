import 'dart:io' show Platform;

/// Whether this is the Android app.
bool get isAndroidApp => Platform.isAndroid;

/// Whether this is the iOS app.
bool get isIosApp => Platform.isIOS;
