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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    afterEvaluate {
        try {
            val android = extensions.findByName("android")
            if (android != null) {
                val getNamespace = android::class.java.methods.firstOrNull { it.name == "getNamespace" }
                val setNamespace = android::class.java.methods.firstOrNull { it.name == "setNamespace" }
                val currentNamespace = getNamespace?.invoke(android)
                if (currentNamespace == null) {
                    // Try to read package name from Manifest or fallback to project group
                    var pkgName: String? = null
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val match = Regex("package=\"([^\"]+)\"").find(manifestText)
                        pkgName = match?.groupValues?.get(1)
                    }
                    setNamespace?.invoke(android, pkgName ?: group.toString())
                }
            }
        } catch (e: Exception) {
            // Safe fallback
        }
    }
}
