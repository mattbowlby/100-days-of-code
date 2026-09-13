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

## Does Omarchy run on aarch64? Mostly, yes

This was the open question and it now has an answer, taken from Arch Linux ARM's
own `core.db` and `extra.db` for aarch64 rather than from hope:

**The two that decide it are both there.**

| | ALARM aarch64 | this laptop |
|---|---|---|
| `hyprland` | 0.56.1-3 | 0.56.2-1 |
| `quickshell` | 0.3.1-1 | 0.3.1-1 |

Quickshell is the *same* version. Hyprland is one patch release behind, which
matters only for the version-specific findings in `NOTES.md` — the
`hl.gesture()` `fingers >= 2` limit was measured on 0.56.2 and should be
re-checked on 0.56.1.

**Of the 162 Omarchy packages that come from Arch `core`/`extra`, 149 are in
ALARM aarch64.** The 13 that are missing are not a problem:

- *x86 hardware support a phone has no use for* — `broadcom-wl`, `intel-lpmd`,
  `intel-media-driver`, `libva-intel-driver`, `thermald`, `vpl-gpu-rt`,
  `qemu-user-static-binfmt`
- *the x86 kernel* — `linux`, `linux-headers`, correctly absent, because the
  device boots postmarketOS's fajita kernel instead
- *desktop applications not built for ARM* — `obsidian`, `obs-studio`, `pinta`,
  `dotnet-runtime`

Not one of them is load-bearing for the session or the shell.

That leaves the 36 packages from Omarchy's own x86_64 repo. Roughly a third are
Apple T2, NVIDIA, Intel and Tuxedo drivers a phone skips outright; the rest are
Omarchy's own small apps and fonts, and the `omarchy` package itself is
`Architecture: any`. Those need rebuilding for aarch64, which is work, but it is
ordinary packaging work rather than a porting problem.

**So the honest verdict: nothing found so far blocks this.** It has still never
been run, and "the packages exist" is a long way from "it boots and the panel
lights up" — but the failure mode everyone feared, that the compositor or shell
simply would not exist for ARM, is not the one you have.

## Not an iPhone

Worth saying once. Apple's boot chain refuses unsigned kernels, so no iPhone can
run this. The only Linux-on-iPhone work (Project Sandcastle) depends on the
checkm8 bootrom bug, covers A7–A11 only, and has no usable GPU or modem stack —
nothing a Wayland compositor could sit on.
