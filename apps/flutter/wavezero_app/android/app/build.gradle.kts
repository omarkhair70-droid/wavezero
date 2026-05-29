plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wavezero.flutter"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.wavezero.flutter"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDir("../../../../android/app/src/main/java/com/wavezero/player/playback")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // Keep aligned with apps/android/app/build.gradle.kts. Do not upgrade Media3,
    // AGP, or compileSdk in this Flutter host bootstrap PR.
    val media3Version = "1.6.1"

    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-datasource:$media3Version")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
