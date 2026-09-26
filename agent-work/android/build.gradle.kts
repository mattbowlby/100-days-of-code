plugins {
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.21" apply false
    // Renders the screens to PNG on a computer, no phone needed: previews/.
    id("app.cash.paparazzi") version "2.0.0-alpha02" apply false
}
