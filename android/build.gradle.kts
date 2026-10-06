allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some plugins (e.g. fluttertoast) still compile against an outdated Android SDK, which
// fails once their AndroidX dependencies require a newer one. Align every Android module
// in the build with the app's compileSdk. Must be registered before the
// evaluationDependsOn(":app") below evaluates the projects.
subprojects {
    afterEvaluate {
        when (val androidExtension = extensions.findByName("android")) {
            is com.android.build.api.dsl.LibraryExtension -> androidExtension.compileSdk = 36
            is com.android.build.api.dsl.ApplicationExtension -> androidExtension.compileSdk = 36
            else -> Unit
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
