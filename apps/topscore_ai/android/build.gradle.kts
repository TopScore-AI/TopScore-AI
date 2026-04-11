import org.gradle.api.JavaVersion
import java.io.File

rootProject.layout.buildDirectory.set(file("${rootDir}/../build"))

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    val subproject = this
    subproject.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${subproject.name}"))

    subproject.plugins.configureEach {
        if (this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin") ||
            this.javaClass.name.contains("com.android.build.gradle.AppPlugin")) {

            // Early-phase: set SDK versions for all modules
            if (subproject.name != "app") {
                val android = subproject.extensions.findByName("android")
                if (android is com.android.build.gradle.BaseExtension) {
                    android.compileSdkVersion(36)
                    android.defaultConfig.targetSdkVersion(36)
                    android.defaultConfig.minSdkVersion(23)

                    android.compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }

            // Late-phase: override EVERYTHING after each plugin has applied its own defaults.
            // This is the nuclear option — it runs AFTER audio_session/receive_sharing_intent
            // have set their own Java 11 or Kotlin 21 targets.
            subproject.afterEvaluate {
                if (subproject.name != "app") {
                    // Determine the effective Java version for this subproject.
                    // We TRY to force Java 17, but if the property is already finalized
                    // (Gradle 8.14+), we read whatever the plugin set and match Kotlin to it.
                    var effectiveJavaVersion = "17"

                    val androidEval = subproject.extensions.findByName("android")
                    if (androidEval is com.android.build.gradle.BaseExtension) {
                        // Try to override to Java 17
                        try {
                            androidEval.compileOptions {
                                sourceCompatibility = JavaVersion.VERSION_17
                                targetCompatibility = JavaVersion.VERSION_17
                            }
                        } catch (_: Exception) {
                            // Finalized — read what was actually set
                            try {
                                effectiveJavaVersion = androidEval.compileOptions
                                    .sourceCompatibility.majorVersion
                            } catch (_: Exception) {}
                        }
                    }

                    // Map Java majorVersion to valid Kotlin JVM target strings.
                    // Java 1.8's majorVersion is "8" but Kotlin expects "1.8".
                    val kotlinJvmTarget = when (effectiveJavaVersion) {
                        "8" -> "1.8"
                        else -> effectiveJavaVersion
                    }

                    // Force Kotlin JVM target to match the effective Java version
                    subproject.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                        kotlinOptions {
                            jvmTarget = kotlinJvmTarget
                        }
                    }
                }

                // Namespace Injection (AGP 8+) — apply to all subprojects
                if (subproject.name != "app") {
                    val androidEval2 = subproject.extensions.findByName("android")
                    if (androidEval2 != null) {
                        try {
                            val getNamespace = androidEval2.javaClass.getMethod("getNamespace")
                            val currentNs = getNamespace.invoke(androidEval2)
                            if (currentNs == null || currentNs.toString().isEmpty()) {
                                val manifestFile = subproject.file("src/main/AndroidManifest.xml")
                                if (manifestFile.exists()) {
                                    val manifestText = manifestFile.readText()
                                    if (manifestText.contains("package=\"")) {
                                        val pkgName = manifestText.substringAfter("package=\"").substringBefore("\"")
                                        if (pkgName.isNotEmpty()) {
                                            androidEval2.javaClass.getMethod("setNamespace", String::class.java).invoke(androidEval2, pkgName)
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {}
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
