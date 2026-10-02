# Omarchy Home: the Samsung app

The Omarchy phone look as an Android home screen, for Samsung phones from 2023
on (Android 12 and later), the Galaxy Z Fold included. It installs like any
other app: no unlocking, no wiping.

- Pages of apps, four across, with page dots and a dock of four, as on iOS.
- Every app on the same frosted rounded-square tile, whatever shape its icon.
- Omarchy's see-through look over your wallpaper, in any of Omarchy's 22
  themes.
- Swipe down on the apps to search. Enter opens the first match.
- On an unfolded Z Fold, two pages side by side.
- Swipe down from the top right for the control panel: Wi-Fi, Bluetooth,
  flashlight and settings tiles, and brightness and volume sliders.

What an Android home-screen app cannot change: the lock screen, the
notification shade and quick settings stay Samsung's. Samsung's free Good Lock
app restyles those.

Previews (rendered on a computer, not photographed on a phone):
`../previews/android-*.png`.

## Installing it

1. On the phone, download `release/OmarchyHome.apk` from this repository:
   open it on GitHub and tap the download button.
2. Open the downloaded file. Android asks whether to allow installs from your
   browser (or My Files): allow it for that app, go back, and tap Install.
   Samsung's Auto Blocker, if you have switched it on, has to be off for this.
   Play Protect may warn that it does not know the app; choose to install
   anyway.
3. Press Home. Android asks which home app to use: pick **Omarchy Home** and
   **Always**. Or later: Settings > Apps > Choose default apps > Home app.

To go back to Samsung's own home screen, choose **One UI Home** there.

## Using it

- **Tap** an app to open it. **Long-press** it to add it to or remove it from
  the dock, see its app info, or uninstall it.
- **Long-press the wallpaper** (between apps) to pick a theme.
- **Swipe down** on the apps to search; tap outside the search panel or press
  Back to close it.
- **Swipe down from the top right** for the control panel. The first time,
  the brightness slider says "Tap to allow brightness": tap it, switch on
  "Allow modifying system settings" for Omarchy Home, and come back. While
  Adaptive brightness is on, the slider says "Auto"; moving it switches
  Adaptive brightness off, as its label then shows. Wi-Fi
  and Bluetooth open Android's own switches for them (apps are not allowed to
  flip those directly).
- **Press Home** while on the home screen to go back to the first page.

The dock starts with your phone, messages, browser and camera apps.

## Omarchy Drive: in the car

The same app also puts an Omarchy dashboard on your car's own screen through
**Android Auto**, the Android version of CarPlay, which Mazda, Hyundai and
Volvo (and most other makers) support. Plug the phone in (or connect
wirelessly, where the car can) and open **Omarchy Home** from Android Auto's
app list. It shows:

- the time, large, and the date, in your Omarchy theme;
- what is playing in any music app, with play/pause and next-track buttons;
- a button that switches to the next Omarchy theme (on the phone too). At
  night a light theme gives way to a dark one, so it does not glare.

Android Auto's own frame -- its app bar and launcher -- stays Google's: Android
Auto lets apps fill in their own screen, not restyle Android Auto itself, and
it only lets navigation apps draw their screen freely, so Omarchy Drive is
listed as one (it shows no map).

**Setting it up, once:**

1. **Let Android Auto show apps that are not from the Play Store.** On the
   phone: Settings > search "Android Auto" > open it. Scroll to the bottom and
   tap **Version** ten times, until it offers developer settings; allow them.
   Then the three-dot menu > **Developer settings** > turn on **Unknown
   sources**.
2. **Let it see what is playing.** Android protects this setting for apps
   installed from a file, so first: Settings > Apps > **Omarchy Home** > the
   three-dot menu (top right) > **Allow restricted settings**. Then Settings >
   Notifications > Advanced settings > **Device and app notifications** (on
   some phones: "Notification access") > turn on **Omarchy Home**. It reads
   no notifications, only which song is playing.
3. In the car, open the app list on the car's screen and tap **Omarchy Home**.

![Omarchy Drive](../previews/android-drivePlaying.png)

## Building it

With the Android SDK (platform 36) and JDK 17 or later:

```bash
./gradlew assembleRelease          # or: gradle assembleRelease
# -> app/build/outputs/apk/release/app-release.apk
gradle recordPaparazziDebug        # redraws the previews (no phone needed)
```

Every build is signed with `app/omarchy-home.keystore`, kept here on purpose
so that a new version installs over the old one from any machine. It is not a
secret. To publish the app anywhere, sign it with a key of your own.

## Status

Built and rendered here; **not yet run on a phone**. Things to check on the
first one: the icons, the dock's default apps, search with the Samsung
keyboard, the wallpaper blurring behind search (on phones where Samsung
leaves blur on), and folding and unfolding a Z Fold.
