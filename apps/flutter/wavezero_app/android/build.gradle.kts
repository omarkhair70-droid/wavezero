import org.gradle.api.file.Directory

plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
}

// Keep the Flutter Android host build output in the location that `flutter run`
// expects: apps/flutter/wavezero_app/build/... instead of android/app/build/...
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}
