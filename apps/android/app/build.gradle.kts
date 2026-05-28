plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

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
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")

    // TODO: Android Media3 integration: add androidx.media3 ExoPlayer, session,
    // datasource, and cache modules when the playback adapter is implemented.
}
