plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    // AGP 9 provides Kotlin support itself (built-in Kotlin): the old
    // `kotlin-android` plugin must no longer be applied here.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shakyaju.pokepod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs the core library desugarer for
        // its java.time APIs below API 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Proposed unique application ID (not registered anywhere). Change it here, in the Kotlin package path and in ios/macos/linux configs if you prefer another.
        applicationId = "com.shakyaju.pokepod"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// AGP 9 built-in Kotlin: JVM target is configured here instead of the removed
// android.kotlinOptions block, matching the Flutter 3.47 template.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
