# Getting this onto a OnePlus 6T

There is no image in this repo to flash, and there will not be one. This repo is
a *session* — Hyprland Lua, Quickshell plugins, a handful of tools. The operating
system underneath it comes from postmarketOS, which already ports the kernel,
device tree and firmware handling for this device and does it far better than a
config repo could.

**Balena Etcher cannot be used.** Etcher writes disk images to removable block
devices. pmaports' own `deviceinfo` for this phone records
`deviceinfo_external_storage="false"` — there is no SD slot — and
`deviceinfo_flash_method="fastboot"`. The 6T is flashed over fastboot, to
partitions, with the phone attached by USB.

## What postmarketOS already gives you

Taken from `device/community/device-oneplus-fajita/deviceinfo` in pmaports,
not from memory:

| | |
|---|---|
| Support tier | **community** (pmOS's tier for devices with real hardware support) |
| Architecture | `aarch64` |
| Panel | 1080x2340 |
| GPU acceleration | `true`, Mesa driver `msm` — so Hyprland is viable |
| Flash method | `fastboot`, generates a boot image |
| Device tree | `qcom/sdm845-oneplus-fajita` |
| External storage | `false` |

Three of those independently confirm guesses this repo had already made:
the panel geometry in `install/devices/fajita.conf`, `DEVICE_GPU=freedreno`
(same driver, `msm` is its kernel-side name), and `DEVICE_HAS_KEYBOARD=0`.

## The path

1. **Unlock the bootloader.** `fastboot flashing unlock`. This **erases the
   phone**. Back up first; there is no way around it.

2. **Build a postmarketOS image.** On a machine with `pmbootstrap`:

   ```bash
   pmbootstrap init          # device: community/oneplus-fajita, UI: none
   pmbootstrap install       # add --fde for full-disk encryption
   ```

   Choose **UI: none**. Omarchy is the UI, and a second desktop installed
   underneath only fights it for the session.

3. **Flash it.**

   ```bash
   pmbootstrap flasher flash_kernel
   pmbootstrap flasher flash_rootfs
   ```

4. **Get non-free firmware on.** Wi-Fi, modem and GPU need blobs; pmaports ships
   `device-oneplus-fajita-nonfree-firmware` for exactly this. Without it, expect
   no Wi-Fi and no cellular.

5. **Install Omarchy and then this port.** Once the phone boots to a shell:
   Omarchy's own packages, then from a checkout of this repo on the device:

   ```bash
   bin/omarchy-phone-diagnose        # confirms the profile resolves on-device
   bin/omarchy-phone-install         # dry run first
   bin/omarchy-phone-install --apply
   ```

   `omarchy-phone-device` matches the running device by its device-tree
   `compatible` string, so the profile should resolve by itself once booted.

## The part nobody has checked

Step 5 is where this stops being a documented path and starts being an open
question. **Omarchy has never been installed on aarch64.** Its package list is
206 packages: 162 come from Arch `core`/`extra`, which Arch Linux ARM mirrors;
36 come from Omarchy's own x86_64 repo and would need rebuilding — though
roughly a third of those are Apple T2, NVIDIA, Intel and Tuxedo drivers a phone
simply skips. The `omarchy` package itself is `Architecture: any`, which is the
encouraging part: its own content is architecture-neutral.

Whether Arch ARM carries `hyprland` and `quickshell` for aarch64 is the single
unanswered question, and it decides whether any of this runs. Both are in Arch's
`extra` on x86_64. Check before committing to a weekend.

## Not an iPhone

Worth saying once. Apple's boot chain refuses unsigned kernels, so no iPhone can
run this. The only Linux-on-iPhone work (Project Sandcastle) depends on the
checkm8 bootrom bug, covers A7–A11 only, and has no usable GPU or modem stack —
nothing a Wayland compositor could sit on.
