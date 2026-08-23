allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/// Android API level every plugin module is compiled against.
val pluginCompileSdk = 36

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Some plugins still pin an old compileSdk (e.g. flutter_quick_video_encoder compiles
// against android-33, which AGP rejects because AndroidX 1.4+ transitives require 34+).
// Registered here, at root-evaluation time, so this listener runs before AGP's own
// afterEvaluate hook locks the DSL. `:app` is left alone: it already tracks
// flutter.compileSdkVersion.
subprojects {
    if (name == "app") return@subprojects
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        val setter = androidExtension.javaClass.methods
            .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
            ?: throw GradleException(
                "Cannot override compileSdk on :$name - the Android Gradle Plugin DSL " +
                    "changed. Update this block in android/build.gradle.kts.",
            )
        setter.invoke(androidExtension, pluginCompileSdk)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
