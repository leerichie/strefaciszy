import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    if (name == "isar_flutter_libs") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                if (namespace == null) {
                    namespace = "dev.isar.flutter.libs"
                }
            }
        }
    }
}

/**
 * Make Kotlin compile target MATCH the Java compile target of each module.
 * This prevents the "Inconsistent JVM-target compatibility" errors.
 */
subprojects {

    fun String.toJvmTarget(): JvmTarget = when (this) {
        "1.8", "8" -> JvmTarget.JVM_1_8
        "11" -> JvmTarget.JVM_11
        "17" -> JvmTarget.JVM_17
        "21" -> JvmTarget.JVM_21
        else -> JvmTarget.JVM_17
    }

    tasks.withType<KotlinCompile>().configureEach {
        // Read this module's Java targetCompatibility if present, else fallback.
        val javaTarget = tasks.withType<JavaCompile>()
            .firstOrNull()
            ?.targetCompatibility
            ?: "17"

        compilerOptions {
            jvmTarget.set(javaTarget.toJvmTarget())
        }
    }
}
