import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads the owner's upload key from android/key.properties,
// which is git-ignored, as is the keystore it points to. See
// docs/release/08-release-build.md. Without it, release builds fail, unless
// ALLOW_DEBUG_SIGNED_RELEASE=true is set for a local toolchain check; such a
// build is signed with the debug key and must never be distributed.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use(::load)
}
val hasUploadKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.deutschhelfer.deutschhelfer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent after the first Play upload (open question Q10).
        applicationId = "com.deutschhelfer.deutschhelfer"
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
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
        }
    }
}

// Checked only when a release task runs, so debug builds never need the key.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any {
        it.project == project && Regex("(assemble|bundle|package)Release").matches(it.name)
    }
    if (releasing && !hasUploadKey) {
        if (System.getenv("ALLOW_DEBUG_SIGNED_RELEASE") != "true") {
            throw GradleException(
                "Release signing needs android/key.properties (see docs/release/08-release-build.md).",
            )
        }
        logger.warn("Signing the release with the DEBUG key. Never distribute this build.")
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
