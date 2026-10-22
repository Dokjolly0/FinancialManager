# Plugins reached from Dart through JNI (package:jni) rather than a method
# channel: R8 sees no Java caller and removes them. Without this rule
# flutter_edge_ai fails to initialize in release builds with
# NoSuchMethodError on SharedPreferencesApiRegistrar.getAll
# (docs/ai-on-device-spike.md, "Pacchetti e build").
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
