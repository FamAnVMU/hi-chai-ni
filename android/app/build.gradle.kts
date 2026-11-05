plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hichinese.hi_chinese"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hichinese.hi_chinese"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            val keyProperties = java.util.Properties()
            if (keyPropertiesFile.exists()) {
                keyPropertiesFile.inputStream().use { keyProperties.load(it) }
            }
            val env = System.getenv()
            val ksPath = env["KEYSTORE_PATH"] ?: keyProperties.getProperty("storeFile")
            val ksPass = env["KEYSTORE_PASSWORD"] ?: keyProperties.getProperty("storePassword")
            val kAlias = env["KEY_ALIAS"] ?: keyProperties.getProperty("keyAlias")
            val kPass = env["KEY_PASSWORD"] ?: keyProperties.getProperty("keyPassword")

            val isReleaseTask = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true) || it.contains("assembleRelease") || it.contains("bundleRelease")
            }

            if (!ksPath.isNullOrEmpty() && !ksPass.isNullOrEmpty() && !kAlias.isNullOrEmpty() && !kPass.isNullOrEmpty()) {
                val resolvedFile = file(ksPath)
                if (resolvedFile.exists()) {
                    storeFile = resolvedFile
                    storePassword = ksPass
                    keyAlias = kAlias
                    keyPassword = kPass
                } else if (isReleaseTask) {
                    throw GradleException("Release keystore file not found at: ${resolvedFile.absolutePath}")
                }
            } else if (isReleaseTask) {
                throw GradleException("Release build requires a valid release keystore configured via environment variables (KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD) or key.properties.")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
