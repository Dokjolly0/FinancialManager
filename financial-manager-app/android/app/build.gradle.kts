import java.util.Properties

plugins {
    id("com.android.application")
    // Kotlin is provided by AGP's built-in Kotlin support (android.builtInKotlin=true),
    // so the standalone Kotlin Gradle Plugin is no longer applied here.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// One upload key for every PC (and later for Play App Signing): its path
// and passwords live in android/key.properties, which is never committed
// (see key.properties.example and docs/build-deploy.md, "Firma Android").
// Without the file, builds fall back to this PC's debug key, as CI does.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = !keystoreProperties.isEmpty

android {
    namespace = "com.alexviolatto.financialmanager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alexviolatto.financialmanager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // LiteRT-LM (on-device AI, plan.md section 33) needs Android 11.
        minSdk = maxOf(flutter.minSdkVersion, 30)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Debug builds use the upload key too, so Google Sign-In needs a
        // single SHA-1 registered whatever PC built the APK.
        val signing = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
        debug {
            signingConfig = signing
        }
        release {
            signingConfig = signing
            // R8 strips methods that plugins call only through JNI.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Release APKs are arm64 only: the on-device AI engines ship arm64
// libraries, and phones that can run a model are arm64. Prebuilt plugin
// libraries for other ABIs (package:jni's) would otherwise make the APK
// claim ABIs Flutter itself was not built for. Debug builds keep every ABI
// for emulators, where on-device AI reports itself unavailable.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.addAll(
            listOf("lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**"),
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
