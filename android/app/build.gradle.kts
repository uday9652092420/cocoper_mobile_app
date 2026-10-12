import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
val releasePropertiesFile = rootProject.file("key.properties")
val requiredReleaseProperties = listOf(
    "storeFile",
    "storePassword",
    "keyPassword",
    "keyAlias",
)
val releaseProperties = Properties()
val releaseKeystoreFile = if (releaseBuildRequested) {
    if (!releasePropertiesFile.isFile) {
        throw GradleException(
            "Release signing configuration is missing: ${releasePropertiesFile.path}. " +
                "Copy android/key.properties.example to android/key.properties, " +
                "then set the existing release keystore path, alias, and passwords.",
        )
    }

    FileInputStream(releasePropertiesFile).use(releaseProperties::load)

    val missingProperties = requiredReleaseProperties.filter { property ->
        releaseProperties.getProperty(property).isNullOrBlank()
    }
    if (missingProperties.isNotEmpty()) {
        throw GradleException(
            "Release signing configuration is incomplete in ${releasePropertiesFile.path}. " +
                "Set these properties: ${missingProperties.joinToString()}.",
        )
    }

    val placeholderProperties = requiredReleaseProperties.filter { property ->
        releaseProperties.getProperty(property).trim().startsWith("REPLACE_WITH")
    }
    if (placeholderProperties.isNotEmpty()) {
        throw GradleException(
            "Release signing configuration still contains example placeholders for: " +
                "${placeholderProperties.joinToString()}. Replace them with values " +
                "for the existing release key; do not use a new key for an existing app.",
        )
    }

    val configuredStoreFile = releaseProperties.getProperty("storeFile").trim()
    val storeFile = File(configuredStoreFile).let { path ->
        if (path.isAbsolute) path else project.file(configuredStoreFile)
    }
    if (!storeFile.isFile) {
        throw GradleException(
            "The release keystore configured by storeFile was not found. " +
                "Absolute paths are used as-is; relative paths are resolved from " +
                "${project.projectDir}. Set storeFile to the existing release " +
                "keystore path in android/key.properties.",
        )
    }

    storeFile
} else {
    null
}

android {
    namespace = "in.cocoper.cocoper_mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.cocoper.cocoper_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseBuildRequested) {
        signingConfigs {
            create("release") {
                keyAlias = releaseProperties.getProperty("keyAlias").trim()
                keyPassword = releaseProperties.getProperty("keyPassword").trim()
                storeFile = requireNotNull(releaseKeystoreFile)
                storePassword = releaseProperties.getProperty("storePassword").trim()
            }
        }
    }
    buildTypes {
        release {
            if (releaseBuildRequested) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
