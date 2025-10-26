import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- load keystore props from android/key.properties ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ⚠️ rename your app/package here
    // old: "com.waah.waah_frontend"
    namespace = "com.dpos.app"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // ⚠️ this must match namespace for release builds on Play Store
        // old: "com.waah.waah_frontend"
        applicationId = "com.dpos.app"

        // you already had these from Flutter
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode    // bump this when you publish a new build
        versionName = flutter.versionName    // e.g. "1.0.0"
    }

    // --- signing for debug + release ---
    signingConfigs {
        // debug stays the same (auto debug keystore)
        getByName("debug") {
            // leave default debug signing
        }

        // new release signing, uses android/key.properties
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
            } else {
                // Fallback: if key.properties isn't present, you'll still be able
                // to build debug, but release build will complain if you try.
                println("⚠️ WARNING: key.properties not fully configured, release signingConfig is incomplete.")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // debug build, nothing special
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            // turn on shrinking to make APK smaller/slicker
            isMinifyEnabled = true
            isShrinkResources = true

            // IMPORTANT: sign with our real keystore, not debug
            signingConfig = signingConfigs.getByName("release")

            // You can also supply proguard rules if Flutter didn't add them already:
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }
}

flutter {
    source = "../.."
}
