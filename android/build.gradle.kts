allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force library subprojects to use JDK 21 compiler via Foojay auto-download,
// avoiding Java 24 type annotation incompatibilities with camera-core.
// Note: :app module is excluded because Flutter Gradle plugin finalizes javaCompiler.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val toolchainService = project.extensions.getByType<JavaToolchainService>()
        tasks.withType<JavaCompile>().configureEach {
            javaCompiler.set(
                toolchainService.compilerFor {
                    languageVersion.set(JavaLanguageVersion.of(21))
                }
            )
        }
    }
}






tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
