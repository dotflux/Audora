plugins {
    id("com.android.application")
    id("kotlin-android")

    id("dev.flutter.flutter-gradle-plugin")
}

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.audora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
   
        applicationId = "com.example.audora"
 
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
            storeFile keystoreProperties["storeFile"] ? file(keystoreProperties["storeFile"]) : null
            storePassword keystoreProperties["storePassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.release
            minifyEnabled false
            shrinkResources false
            
        }

        debug {
            signingConfig = signingConfigs.release
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.media:media:1.7.1")
    implementation("androidx.palette:palette:1.0.0")
}
