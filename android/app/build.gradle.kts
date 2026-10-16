plugins {
    id("com.android.application")
    // Keep or remove based on whether you migrated to built-in Kotlin (android.builtInKotlin=false)
    id("kotlin-android")
}

android {
    namespace = "com.your.package" // Replace with your actual package name
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.your.package" // Replace with your actual package name
        minSdk = 21 // Or flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Force aligned AndroidX versions to fix the 15 AAR metadata mismatch issues
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.core:core:1.13.1")
            force("androidx.fragment:fragment:1.7.1")
            force("androidx.window:window:1.2.0")
            force("androidx.window:window-java:1.2.0")
            force("androidx.activity:activity:1.8.1")
            force("androidx.lifecycle:lifecycle-runtime:2.7.0")
            force("androidx.lifecycle:lifecycle-livedata:2.7.0")
            force("androidx.lifecycle:lifecycle-livedata-core:2.7.0")
            force("androidx.lifecycle:lifecycle-livedata-core-ktx:2.7.0")
            force("androidx.lifecycle:lifecycle-viewmodel:2.7.0")
            force("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.7.0")
            force("androidx.lifecycle:lifecycle-process:2.7.0")
            force("androidx.exifinterface:exifinterface:1.4.1")
            force("androidx.annotation:annotation-experimental:1.4.0")
        }
    }
}

flutter {
    source = "../.."
}
