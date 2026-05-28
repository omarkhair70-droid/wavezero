import com.google.firebase.appdistribution.gradle.firebaseAppDistribution

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.firebase.appdistribution")
}

val firebaseAppId: String? = providers.gradleProperty("firebaseAppId")
    .orElse(providers.environmentVariable("FIREBASE_APP_ID"))
    .orNull

android {
    namespace = "com.wavezero.player"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.wavezero.player"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        getByName("debug") {
            firebaseAppDistribution {
                artifactType = "APK"
                groups = "internal-testers"
                releaseNotes = "WaveZero Android debug build for internal Media3 playback proof testing."
                firebaseAppId?.let { appId = it }
            }
        }
    }
}

dependencies {
    // Media3 1.10.x requires compileSdk 36. Keep 1.6.1 until the Android
    // Gradle Plugin and compileSdk are upgraded together in a dedicated change.
    val media3Version = "1.6.1"

    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-datasource:$media3Version")

    testImplementation("junit:junit:4.13.2")
}
