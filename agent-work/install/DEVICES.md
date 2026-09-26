# Which phones this can run on

The shell in this repo, meaning the home screen, bar and control centre,
works at any screen size. It already lays itself out for a 375x667 iPhone SE
2-sized panel, a 360-412px-wide Samsung, a Galaxy Z Fold cover screen, and the
Fold's unfolded inner screen, where it shows two pages side by side. What limits
where it runs is not the shell. It is whether a phone can boot Linux at all.

Installing this port means replacing the phone's operating system. That needs
two things from the phone:

1. **An unlockable bootloader.** Without it, the phone refuses any kernel its
   maker did not sign, and there is nothing to flash.
2. **A Linux kernel port for its chip**, with the display, touch, GPU, modem
   and battery drivers working. postmarketOS is where these live, and
   `BRING-UP.md` explains why this repo builds on it rather than duplicating it.

Checked in September 2026.

| Device | Bootloader | Linux kernel port | Can it run this port? |
|---|---|---|---|
| OnePlus 6T (the reference device) | Unlockable (`fastboot flashing unlock`) | postmarketOS, community tier | **Yes.** See `BRING-UP.md`. |
| iPhone SE (2nd gen) | Locked. Apple's boot chain accepts only kernels Apple signed. | None. The only Linux-on-iPhone effort, Project Sandcastle, needs the checkm8 bootrom exploit (A7-A11 chips at most), in practice supports only A10 devices (iPhone 7/7 Plus, iPod touch 7th gen), and has no usable GPU or modem. The SE 2 uses an A13. | **No.** No technique exists to boot it. |
| Samsung Galaxy phones from 2023 onward (S23-S25, A14-A56, Z Flip 5-7, Z Fold 5-7) | US models: never unlockable. Every other region: unlockable up to One UI 7. **One UI 8 removed bootloader unlocking in every region**, on any Samsung that takes it -- older models included; the Galaxy A53 got it in October 2025. Its bootloader no longer contains the unlock code, so it cannot be forced either. | None. The newest Samsung phone in pmaports is from 2022 (Galaxy A53, `samsung-a53x`), and that port is archived. | **No**, in practice. A non-US unit that has *never* taken One UI 8 could still be unlocked, but it would then need a kernel port that does not exist yet. |
| Samsung Galaxy Z Fold 8 | Ships with One UI 9, so it cannot be unlocked. | None. | **No.** |

## What would change this

- **Samsung restoring OEM unlock.** It would have to ship a bootloader
  update that contains the unlock code again. Until then, no software can
  install anything on these phones.
- **A mainline kernel port for a 2023+ Snapdragon or Exynos Samsung.** This is
  months of work per device, and only worth doing once the bootloader question
  has an answer.
- **A different phone.** Many devices that can already boot postmarketOS are
  cheap second-hand and run this port: the OnePlus 6/6T, Pixel 3a, Xiaomi Poco
  F1 and SHIFT6mq among them. Every layout in this repo already fits their
  screens.

## Sources

- Samsung One UI 8 removing bootloader unlock:
  [Android Authority](https://www.androidauthority.com/samsung-bootloader-unlocking-disabled-one-ui-8-3581366/),
  [9to5Google](https://9to5google.com/2025/07/26/samsung-galaxy-one-ui-8-bootloader-unlock/)
- postmarketOS device ports: `device/*/device-samsung-*` in
  [pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports), checked
  for any Samsung device released in 2023 or later (there are none).
