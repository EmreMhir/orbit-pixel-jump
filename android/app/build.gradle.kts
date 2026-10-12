import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signing = Properties()
// Pass the app ID with the same Flutter build arguments as the ad unit IDs.
// This avoids environment-variable casing differences on Windows.
val dartDefines = (project.findProperty("dart-defines") as? String)
    ?.split(",")?.filter { it.isNotBlank() }?.associate {
        val pair = String(Base64.getDecoder().decode(it), Charsets.UTF_8).split("=", limit = 2)
        pair[0] to pair.getOrElse(1) { "" }
    } ?: emptyMap()
val admobAppId = dartDefines["ADMOB_APP_ID"]
    ?: providers.gradleProperty("admobAppId").getOrElse("ca-app-pub-3940256099942544~3347511713")
if (dartDefines["TEST_ADS"] == "false" &&
    (!Regex("ca-app-pub-[0-9]{16}~[0-9]{10}").matches(admobAppId) ||
        admobAppId.contains("3940256099942544"))) {
    throw GradleException("Live ads require a real ADMOB_APP_ID. Use tool/build_release.dart.")
}
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signing.load(it) }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (releaseRequested && !signingFile.exists()) {
    throw GradleException("Release signing requires android/key.properties. See docs/RELEASE_TR.md.")
}

android {
    namespace = "com.emredev.orbitjump"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.emredev.orbitjump"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }
    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
                storeFile = file(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles("proguard-rules.pro")
        }
    }
}
kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}
flutter { source = "../.." }
