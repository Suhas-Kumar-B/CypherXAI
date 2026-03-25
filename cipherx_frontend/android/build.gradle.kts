buildscript {
    ext {
        // Kotlin version
        kotlin_version = '1.8.20'
        
        // Android Gradle Plugin version
        agp_version = '8.1.0'
    }
    
    repositories {
        google()
        mavenCentral()
    }
    
    dependencies {
        classpath("com.android.tools.build:gradle:$agp_version")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
    
    // Configure all projects
    afterEvaluate {
        if (project.hasProperty("android")) {
            android {
                compileSdk = 33
                
                defaultConfig {
                    minSdk = 21
                    targetSdk = 33
                    
                    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
                }
                
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
                
                kotlinOptions {
                    jvmTarget = '11'
                    freeCompilerArgs += [
                        "-Xjvm-default=all",
                        "-opt-in=kotlin.RequiresOptIn"
                    ]
                }
                
                buildFeatures {
                    viewBinding = true
                    buildConfig = true
                }
            }
        }
    }
}

// Configure build directory
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure the app module is evaluated before other modules
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Task to print project information
tasks.register("printProjectInfo") {
    doLast {
        println("Project: ${rootProject.name}")
        println("Root Directory: ${rootProject.projectDir}")
        println("Build Directory: ${rootProject.buildDir}")
    }
}
