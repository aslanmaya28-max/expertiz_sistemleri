import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Gerçek yükleme anahtarı depo dışında; yerel özellik dosyası Git tarafından yok sayılır.
val signingFile = file(System.getenv("YB_ANDROID_KEY_PROPERTIES") ?: "../key.properties")
val signingValues = Properties().apply {
    if (signingFile.isFile) signingFile.inputStream().use { load(it) }
}
// Üst görevler (assemble/build/bundle) de release alt görevlerini içerir.
// Grafiği kontrol etmek, yalnız CLI görev adını kontrol eden boşluğu kapatır.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) } &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword").any { signingValues.getProperty(it).isNullOrBlank() }) {
        throw GradleException("Yayın imzası eksik. README içindeki key.properties adımlarını tamamlayın; debug imzasıyla yayın üretilmez.")
    }
}

android {
    namespace = "com.yerimebak.app"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yerimebak.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = maxOf(36, flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingValues.getProperty("storeFile") != null) {
            create("upload") {
                storeFile = file(signingValues.getProperty("storeFile"))
                storePassword = signingValues.getProperty("storePassword")
                keyAlias = signingValues.getProperty("keyAlias")
                keyPassword = signingValues.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
