plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Play builds sign with the private upload key from CI secrets
// (the `play` job sets these). Everything else uses the sideload key.
val uploadKeystore: String? = System.getenv("UPLOAD_KEYSTORE")

android {
    namespace = "com.adhdtax.adhd_tax"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by flutter_local_notifications for scheduling on older
        // Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.adhdtax.adhd_tax"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Personal sideload key, committed so every CI build has the same
        // signature: Android only installs an update over the previous
        // version (keeping local data) when signatures match, and Google
        // Sign-In's Android client is registered against this key's SHA-1.
        // Google Play builds use the upload key below instead.
        create("sideload") {
            storeFile = file("sideload.jks")
            storePassword = "adhdtax-sideload"
            keyAlias = "sideload"
            keyPassword = "adhdtax-sideload"
        }
        uploadKeystore?.let { path ->
            create("upload") {
                storeFile = file(path)
                storePassword = System.getenv("UPLOAD_STORE_PASSWORD")
                keyAlias = System.getenv("UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (uploadKeystore != null) "upload" else "sideload")
            // Release builds are shrunk with R8; keep plugin classes that are
            // only reached via reflection/registration (see the rules file).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
