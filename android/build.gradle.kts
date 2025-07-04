import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔧 Flutter 빌드 디렉토리 재지정
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// 🔧 서브프로젝트의 빌드 디렉토리 정렬
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 🔄 :app 평가를 모든 서브프로젝트가 의존하게 만듦
subprojects {
    project.evaluationDependsOn(":app")
}

// 🧹 `./gradlew clean` 명령용 클린 태스크
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
