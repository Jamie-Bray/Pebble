import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    requiredSigningKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

fun dartDefines(): Map<String, String> {
    val raw = project.findProperty("dart-defines")?.toString().orEmpty()
    if (raw.isBlank()) return emptyMap()
    return raw.split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .mapNotNull { define ->
            val index = define.indexOf("=")
            if (index <= 0) null else define.substring(0, index) to define.substring(index + 1)
        }
        .toMap()
}

android {
    namespace = "com.vix.pebble_routines"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.vix.pebble_routines"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}

tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }.configureEach {
    doFirst {
        check(hasReleaseSigning) {
            "Release signing is not configured. Copy android/key.properties.example to android/key.properties and fill in the upload keystore values."
        }
        val defines = dartDefines()
        check(defines["APP_ENV"] == "production") {
            "Release builds must pass --dart-define=APP_ENV=production."
        }
        check(!defines["SUPABASE_URL"].isNullOrBlank() && !defines["SUPABASE_ANON_KEY"].isNullOrBlank()) {
            "Production release builds require SUPABASE_URL and SUPABASE_ANON_KEY."
        }
        check(defines["SUPABASE_URL"]?.contains("lxvrvrrxdjbrjwsxzppl.supabase.co") != true) {
            "Production release builds cannot use the staging Supabase URL."
        }
        check(defines["REVENUECAT_ANDROID_API_KEY"]?.startsWith("goog_") == true) {
            "Android release builds require the RevenueCat Android SDK key starting with 'goog_'."
        }
    }
}
