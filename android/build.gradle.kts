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

// Flutter passes every supported ABI by default. Keep the default at
// arm64-v8a, while still allowing an explicit --target-platform override.
val appProject = project(":app")
val requestedTarget = appProject.findProperty("target-platform")?.toString()
if (requestedTarget == null ||
    requestedTarget == "android-arm,android-arm64,android-x64"
) {
    appProject.extensions.extraProperties.set("target-platform", "android-arm64")
}
// Some Flutter plugins still declare an old compileSdk. AGP 9 verifies
// transitive AndroidX metadata against every library module, so keep plugin
// modules on the same compile SDK as the app.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.api.dsl.LibraryExtension) {
            android.compileSdk = 36
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
        )
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
