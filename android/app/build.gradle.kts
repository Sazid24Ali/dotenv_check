plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.dotenv_check"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"
    compileOptions {
        // Essential for desugaring: Set source and target compatibility to Java 1.8
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // Added for robust desugaring: enable desugaring for core libraries
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.dotenv_check"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Required for core library desugaring and apps with many dependencies
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // If you had a signing config here, it would go below.
            // Example: signingConfig = signingConfigs.getByName("release")
        }
        debug {
            // Debug specific configurations if any
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dependency for core library desugaring
    // Using a recent stable version.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}