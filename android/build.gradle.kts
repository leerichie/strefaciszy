allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
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
            // No import needed; fully qualified type works in Kotlin DSL.
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                if (namespace == null) {
                    namespace = "dev.isar.flutter.libs"
                }
            }
        }
    }
}
