plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("app.cash.paparazzi")
}

android {
    namespace = "dev.omarchyphone.launcher"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.omarchyphone.launcher"
        // Android 12: the oldest any phone Samsung sold from 2023 on runs
        // (the Galaxy A04 shipped with it). Also the first with window blur.
        minSdk = 31
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    // One key, kept in the repository, so every build of the app -- from any
    // machine -- installs over the last as an update instead of being refused
    // for a different signature. It is not a secret: this is a sideloaded
    // hobby app. To publish it anywhere, sign with a key of your own
    // (README.md).
    signingConfigs {
        create("omarchy") {
            storeFile = file("omarchy-home.keystore")
            storePassword = "omarchy-home"
            keyAlias = "omarchy-home"
            keyPassword = "omarchy-home"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("omarchy")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.getByName("omarchy")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.03.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.core:core-ktx:1.17.0")
    testImplementation("junit:junit:4.13.2")
}
