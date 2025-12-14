import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- load keystore props from android/key.properties ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
var hasReleaseKeystore = false
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // final package / Play app id
    namespace = "com.dpos.app"

    // Keep these sourced from Flutter toolchain
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Modern toolchains (Flutter 3.22+ prefers Java 17 / AGP 8+)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // immutable on Play after first upload
        applicationId = "com.dpos.app"

        // from Flutter (pubspec.yaml version: x.y.z+code)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    // --- signing for debug + release ---
    signingConfigs {
        // default debug keystore
        getByName("debug")

        // release uses android/key.properties; fallback handled in buildTypes.release
        create("release") {
            val keyAliasProp = keystoreProperties["keyAlias"] as String?
            val keyPasswordProp = keystoreProperties["keyPassword"] as String?
            val storeFileProp = keystoreProperties["storeFile"] as String?
            val storePasswordProp = keystoreProperties["storePassword"] as String?

            if (
                keyAliasProp != null &&
                keyPasswordProp != null &&
                storeFileProp != null &&
                storePasswordProp != null
            ) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = file(storeFileProp)
                storePassword = storePasswordProp
                storeType = "jks"
                hasReleaseKeystore = true
            } else {
                println("key.properties missing/incomplete -> release signing not configured.")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            // shrink + optimize for Play
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback lets CI produce an artifact even when secrets aren't provided
                println("Warning: release keystore not present; using debug signing for release build.")
                signingConfigs.getByName("debug")
            }

            // Use default Flutter proguard unless you have custom rules:
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    // (Optional) If you ever ship native libs, this helps Play prelaunch symbols
    // ndkVersion = flutter.ndkVersion

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

// Windows lint cache occasionally gets locked by parallel processes, breaking release builds.
tasks.whenTaskAdded {
    if (name.contains("lint", ignoreCase = true) && name.contains("Release")) {
        enabled = false
    }
}

// AGP 8+ spawns lintVitalAnalyzeRelease; force-disable all lintVital variants to unblock aab/apk.
tasks.matching { it.name.contains("lintVital", ignoreCase = true) }.configureEach {
    enabled = false
}
