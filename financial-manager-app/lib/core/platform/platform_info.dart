import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether this is the Android app. Code that must also run in the browser
/// asks this instead of dart:io's Platform, which throws on the web.
bool get isAndroidApp => !kIsWeb && Platform.isAndroid;

/// Whether this is the iOS app.
bool get isIosApp => !kIsWeb && Platform.isIOS;
