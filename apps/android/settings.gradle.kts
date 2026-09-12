pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "FloentlyNativeAndroid"

include(":shared")
project(":shared").projectDir = file("shared")

include(":FloentlyLearn:app")
project(":FloentlyLearn:app").projectDir = file("FloentlyLearn/app")

include(":FloentlyRead:app")
project(":FloentlyRead:app").projectDir = file("FloentlyRead/app")
