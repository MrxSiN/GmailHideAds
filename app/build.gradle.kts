plugins {
    id("com.android.application")
}

val appVersion = "2.1.0"

val envKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val envKeystoreAlias = System.getenv("ANDROID_KEYSTORE_ALIAS")
val envKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val envKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")

android {
    namespace = "my.MrxSiN.gmailhideads"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    /*
     * Release signing is supplied by the environment so that no credential ever
     * reaches version control. Local builds without those variables stay
     * unsigned instead of failing.
     */
    val releaseSigningConfig = if (
        !envKeystorePath.isNullOrBlank() &&
        !envKeystoreAlias.isNullOrBlank() &&
        !envKeystorePassword.isNullOrBlank() &&
        !envKeyPassword.isNullOrBlank() &&
        file(envKeystorePath).isFile
    ) {
        signingConfigs.create("release") {
            storeFile = file(envKeystorePath)
            storePassword = envKeystorePassword
            keyAlias = envKeystoreAlias
            keyPassword = envKeyPassword
        }
    } else {
        null
    }

    defaultConfig {
        applicationId = "io.github.mrxsin.gmailhideads"
        minSdk = 26
        targetSdk = 36
        versionCode = 4
        versionName = appVersion
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets {
        // The JVM suite (frozen legacy oracle, parity, robustness and
        // benchmarks) also runs on devices: connectedDebugAndroidTest.
        getByName("androidTest").java.srcDir("src/test/java")
    }

    // -PbenchmarkRelease runs the instrumented tests against the release build
    // (not debuggable: JIT on, CheckJNI off, optimized native code), signed with
    // the debug key. Local benchmarking only.
    if (project.hasProperty("benchmarkRelease")) {
        testBuildType = "release"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            releaseSigningConfig?.let { signingConfig = it }
            if (project.hasProperty("benchmarkRelease")) {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            merges += "META-INF/xposed/*"
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*"
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }

    // The Brainfuck policy core: brainfuck/src/*.bf compiled ahead of time by
    // tools/bftool/gen.py into cpp/generated/, then by the NDK into
    // libgmailbf.so. The generated C is committed, so a plain build needs no
    // Python; checkBrainfuck (part of `check` and CI) rejects stale output.
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            output.outputFileName.set("GmailHideAds-v$appVersion.apk")
        }
    }
}

dependencies {
    implementation("org.luckypray:dexkit:2.2.0")
    compileOnly("io.github.libxposed:api:102.0.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("io.github.libxposed:api:102.0.0")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestCompileOnly("io.github.libxposed:api:102.0.0")
}

// ---- Brainfuck core: generation, checks and the host build used by JVM tests.
//
// Generation runs bfcc, the Brainfuck compiler written in Brainfuck, built
// from the committed tools/bfcc/bfcc.generated.c with the host C compiler: no
// Python. Python remains for the test oracle and the bootstrap check
// (tools/bfcc/selfhost.py).

val python = if (System.getProperty("os.name").startsWith("Windows")) "python" else "python3"
val isWindows = System.getProperty("os.name").startsWith("Windows")
val bfccDir = rootProject.file("tools/bfcc")
val bfccExe = rootProject.layout.buildDirectory.file(if (isWindows) "bfcc/bfcc.exe" else "bfcc/bfcc").get().asFile
val hostCoreLibrary = rootProject.layout.buildDirectory.file(
    "bfhost/" + System.mapLibraryName("gmailbf")
).get().asFile

/** The host C compiler: $CC or cc, or MSVC (found with vswhere) on Windows. */
fun hostCompile(output: File, sources: List<File>): List<String> {
    if (!isWindows) {
        return listOf(System.getenv("CC") ?: "cc", "-O2", "-std=c11", "-o", output.absolutePath) +
            sources.map { it.absolutePath }
    }
    val vswhere = File(
        System.getenv("ProgramFiles(x86)") ?: "C:/Program Files (x86)",
        "Microsoft Visual Studio/Installer/vswhere.exe"
    )
    if (!vswhere.isFile) {
        throw GradleException("No host C compiler: install Visual Studio Build Tools (C++).")
    }
    val found = providers.exec {
        commandLine(
            vswhere.absolutePath, "-latest", "-products", "*", "-requires",
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"
        )
    }.standardOutput.asText.get()
    val vcvars = File(found.trim(), "VC/Auxiliary/Build/vcvars64.bat")
    if (!vcvars.isFile) {
        throw GradleException("No host C compiler: MSVC x64 tools not found.")
    }
    // A batch file keeps cmd's quoting rules away from the paths; objects go
    // to the output directory, the batch file's working directory.
    val script = File(output.parentFile, "build-" + output.nameWithoutExtension + ".bat")
    script.writeText(
        "@set \"PATH=%PATH%;${vswhere.parentFile.absolutePath}\"\r\n" +
            "@call \"${vcvars.absolutePath}\" >nul\r\n" +
            "@cd /d \"${output.parentFile.absolutePath}\"\r\n" +
            "cl /nologo /O2 /std:c11 /Fe\"${output.name}\" " +
            sources.joinToString(" ") { "\"${it.absolutePath}\"" } + "\r\n"
    )
    return listOf("cmd", "/c", script.absolutePath)
}

val buildBfcc by tasks.registering(Exec::class) {
    group = "brainfuck"
    description = "Builds bfcc, the Brainfuck compiler, from the committed tools/bfcc/bfcc.generated.c."
    inputs.files(fileTree(bfccDir) { include("*.c", "*.h") })
    outputs.file(bfccExe)
    workingDir = bfccDir
    doFirst {
        bfccExe.parentFile.mkdirs()
        commandLine(hostCompile(bfccExe, listOf(File(bfccDir, "bfcc_host.c"), File(bfccDir, "bfcc_main.c"))))
    }
}

val generateBrainfuck by tasks.registering(Exec::class) {
    group = "brainfuck"
    description = "Lints brainfuck/src and regenerates the AOT C source, ABI constants and memory map (bfcc)."
    dependsOn(buildBfcc)
    workingDir = rootDir
    commandLine(bfccExe.absolutePath, "gen")
}

val checkBrainfuck by tasks.registering(Exec::class) {
    group = "brainfuck"
    description = "Fails when the generated C, ABI or memory map files are stale (bfcc)."
    dependsOn(buildBfcc)
    workingDir = rootDir
    inputs.dir(rootProject.file("brainfuck"))
    inputs.dir("src/main/cpp/generated")
    outputs.upToDateWhen { false }
    commandLine(bfccExe.absolutePath, "gen", "--check")
}

val buildHostCore by tasks.registering(Exec::class) {
    group = "brainfuck"
    description = "Builds libgmailbf for the host JVM (parity tests run the shipped AOT C)."
    dependsOn(checkBrainfuck)
    workingDir = rootDir
    inputs.dir("src/main/cpp")
    outputs.file(hostCoreLibrary)
    commandLine(python, "tools/bftool/hostlib.py", System.getProperty("java.home"), hostCoreLibrary.absolutePath)
}

val testBrainfuck by tasks.registering(Exec::class) {
    group = "brainfuck"
    description = "Toolchain, reference-vs-IR-vs-AOT and randomized program tests (Python)."
    dependsOn(checkBrainfuck)
    workingDir = rootDir
    commandLine(python, "-m", "unittest", "discover", "-s", "tests/compiler", "-v")
}

tasks.named("check") {
    dependsOn(checkBrainfuck, testBrainfuck)
}

tasks.withType<Test>().configureEach {
    dependsOn(buildHostCore)
    inputs.file(hostCoreLibrary)
    systemProperty("gmailbf.hostlib", hostCoreLibrary.absolutePath)
    systemProperty("gmailbf.parityCases", project.findProperty("parityCases") ?: "20000")
}
