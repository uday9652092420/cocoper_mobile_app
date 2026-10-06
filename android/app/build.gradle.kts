import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties()
val releaseFile = rootProject.file("key.properties")
if (releaseFile.exists()) releaseProperties.load(FileInputStream(releaseFile))
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) } && !releaseFile.exists()) {
    throw GradleException("Release signing is required. Create android/key.properties from key.properties.example.")
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

    if (releaseFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = releaseProperties["keyAlias"] as String
                keyPassword = releaseProperties["keyPassword"] as String
                storeFile = file(releaseProperties["storeFile"] as String)
                storePassword = releaseProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            if (releaseFile.exists()) signingConfig = signingConfigs.getByName("release")
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
