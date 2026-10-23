# ios-oneplus3

**Apple's iOS 16.7.16 running on a OnePlus 3 (`oneplus3`, Snapdragon 820), with GPU-accelerated graphics.**

This project ports Apple's open-source XNU kernel (xnu-8796, the iOS 16 generation) to the OnePlus 3 and runs the **unmodified iOS 16.7.16 (20H392) userland of the iPhone SE (2nd gen)** on it: launchd, the system daemons, backboardd, SpringBoard and the stock apps. It is a fork of [joranv1/ios-sailfish](https://github.com/joranv1/ios-sailfish), which brought the same kernel up on a Google Pixel 1; that history is kept, and the OnePlus work starts at the patch series `0184`-`0190` on top of ios-sailfish main.

> Experimental, not a usable phone OS. Many things are missing or stubbed (see below) and Apple's security model is mostly switched off. It installs into the `userdata` partition and so **erases Android's user data**.

## Why this port is much easier than the A71 / A05s ports

The OnePlus 3 and the Pixel 1 are nearly the same platform. The A71 port (SM7150 → A71 SM7125) and the A05s port (SM6225) had to deal with different SoC families, different touch ICs, and different PMICs. OP3 from sailfish is mostly a device-tree / GPIO-mapping exercise:

| Area | Pixel 1 (`sailfish`) | OnePlus 3 (`oneplus3`) | Source of truth |
| --- | --- | --- | --- |
| SoC | MSM8996Pro (SD821) | MSM8996 (SD820) | same Kryo custom cores, ARMv8.0 |
| GPU | Adreno 530 @ 600 MHz | Adreno 530 @ 624 MHz | same chip, same TZ interface |
| Wi-Fi | QCA6174 over PCIe | QCA6174 over PCIe | same driver (patches 0169-0181) |
| Touch IC | Synaptics S3708 (RMI4 F12) | Synaptics S1302 (RMI4 F12) | same protocol, different BLSP/I2C/GPIOs |
| Panel | Samsung command-mode AMOLED 1080x1920 | Samsung command-mode AMOLED 1080x1920 | same 24bpp format, different init sequence (left to bootloader) |
| PMIC | PMI8994 + PM8994 | PMI8994 + PM8994 | same chip family, same SPMI arbiter |
| Buttons | Power + vol-up + vol-down (vol-down = Home) | Power + vol-up + vol-down + capacitive Home/back/recents | OP3 has a real Home button via the touch IC's F30; no software mapping |
| RAM | 4 GB | 6 GB | same upper-bank scheme; 0x100000000 + 0x17a00000 on OP3 vs + 0x3f200000 on Pixel 1 |
| iOS identity | iPhone 8 (iPhone10,1 / D20AP) | iPhone SE 2nd gen (iPhone12,8 / N104AP) | SE2 supports iOS 16; original SE1 (iPhone8,4) tops out at iOS 15 |

## Status (2026-10-23)

* **Mostly-tested drafts**: like the A71 PR, the OP3 patches in this branch are drafts. Constants fall into two categories:
  * **VERIFIED from `Gaurav241/device_oneplus_oneplus3`**: touch IC identity is Synaptics S1302 (the chip self-reports via RMI4 F01; the OP3 stock kernel exposes `/proc/s1302/virtual_key`, `/proc/s1302/key_rep`, and `/proc/touchpanel/<g>_enable` — see `lineagehw/touch/KeyDisabler.cpp`, `KeySwapper.cpp`, `TouchscreenGesture.cpp`). Kernel base `0x80000000`, page size `4096`, boot partition 64 MB, userdata 53.5 GB, kernel image `Image.gz-dtb` (DTB embedded in stock boot.img).
  * **DTB-dependent DRAFT** (the OP3 kernel image embeds the DTB, so the remaining constants can only be confirmed by unpacking the OP3 stock `boot.img`): BLSP QUP4 base, SDA/SCL GPIOs, reset/attention GPIOs, F12 max-x/max-y, volume GPIOs, DRAM carve-out size, perf cluster OPP table. Each is flagged with `TODO_VERIFY(OP3 DTB)` in the source and the corresponding DTB property name is listed in the porting plan's Table 4.
* The author has an unlocked OP3, so the first real bring-up pass will replace each remaining `TODO_VERIFY` with a verified value and clear the corresponding probe line in `tools/sweet-log-pull.sh`.

## What is expected to work

| Area | Expected state on first boot | Patch |
| --- | --- | --- |
| Boot | Stock OnePlus bootloader → `fastboot boot` of our shim → XNU. Nothing is flashed to boot partitions | shim (mirrored from build-pixel.sh) |
| CPU | All 4 Kryo cores via PSCI (same as Pixel 1) | 0088-sweet-pixel1-smp-mpidr (reused) |
| Memory | ~5.7 GB of the upper DDR bank (vs ~1 GB on Pixel 1) | 0188-oneplus3-adt-ram |
| Storage | Same UFS host driver as the Pixel 1 (msm8996 UFS 2.0) | 0028-0034 (reused) |
| iOS userland | iPhone SE 2 (N104AP) iOS 16.7.16 root filesystem + shared cache | n/a |
| GPU | Adreno 530 at 600 MHz, same Mesa/freedreno path as Pixel 1 | 0119-0150 (reused) |
| Display | Samsung command-mode 1080x1920 panel, presented as iPhone SE2 (750x1334 @2x), scaled 1.44x | 0186-oneplus3-panel-dcs |
| Touch | Synaptics S1302 RMI4 F12 over I2C 0x20 on BLSP1 QUP4 | 0185-oneplus3-touch-rmi4 |
| Buttons | Power, vol-up, vol-down; OP3 hardware Home via touch IC's F30 (delivered as HID) | 0187-oneplus3-keys |
| Wi-Fi | QCA6174, same as Pixel 1 (interrupt-driven) | 0169-0181 (reused) |
| Battery | PMI8994 fuel gauge (same as Pixel 1) | 0114-sailfish-battery-pmi8994 (reused) |
| Identity | iPhone SE 2 (iPhone12,8 / N104AP) | 0188-oneplus3-adt-ram |
| Activation | mobileactivationd's "Hactivation" path | n/a |

## What does not work (yet)

* Same gaps as the Pixel 1 base: no Bluetooth, cellular, audio, camera, sensors, GPS, Touch ID, SEP, hardware video decode, Metal.
* The iPhone SE 2 identity (iPhone12,8 / N104AP) has not been boot-tested; if MobileGestalt or SpringBoard reject it, fall back to iPhone 8 (iPhone10,1 / D20AP) — the d20ap ADT is already extracted from the iPhone 8 IPSW and the swap is a one-line change in `tools/mkadt.py --oneplus3`.
* The original iPhone SE (iPhone8,4 / N61AP) does NOT support iOS 16 — using it would require dropping to iOS 15.7, which the project does not ship. The substitution to SE2 is noted in `0188-oneplus3-adt-ram.patch`.

## How it boots

```
OnePlus bootloader (aboot, unlocked)
  -> fastboot boot oneplus3-boot.img   (temporary; nothing is flashed)
  -> shim: stops the watchdog, loads the payload appended to the kernel
  -> XNU Mach-O + generated ADT + boot-args + GPU firmware
  -> XNU -> UFS driver -> HFS+ root in the userdata partition
  -> dyld + shared cache -> launchd -> daemons -> backboardd (+ sweetgl.dylib) + SpringBoard
```

Same as the Pixel 1: no serial console; the kernel log goes to a persistent 4 MiB ring at the end of `userdata` and to the RAM console (pstore) that survives a warm reset; both are read from TWRP (`tools/sweet-log-pull.sh`).

## How to do it yourself

You need a OnePlus 3 (`oneplus3`, original SD820 — the SD821 3T is a separate fork) with an **unlocked bootloader**, a Mac with Xcode 15.4 and the KDK 13.5 (for the kernel build), and a recent TWRP for oneplus3 (booted temporarily, never flashed). **Everything on `userdata` is lost.** Bootloaders, recovery, modem and persist are never touched. Keep your partition backups and any device dumps out of git (`.gitignore` covers `backup/`, `research/`, `logs/`).

0. **Back up the phone.** Boot TWRP temporarily and pull at least `persist`, `modemst1`, `modemst2`, `fsg`, `fsc` and `boot`, `dtbo`, `vbmeta`. They contain per-device calibration data. Keep them off git.

1. **Kernel:** `tools/xnu-build-local.sh xnu/out-local-NNNN` builds XNU with all patches in `xnu/patches/` (blacktop/darwin-xnu-build, Xcode 15.4 and KDK 13.5 unpacked in `research/`). The patch series runs `0001`-`0183` (ios-sailfish) and `0184`-`0190` (this port).

2. **iOS root:** download the iPhone SE 2 IPSW `iPhone_4.7_N104_16.7.16_20H392_Restore.ipsw` (NOT the SE1 IPSW — SE1 / iPhone8,4 is iOS 15 only). Build the image with `sudo tools/mkiosroot-mac.sh OS.dmg SYSTEMOS.dmg APPOS.dmg ios16-root.img`. Before flashing, attach it read-write on the Mac (`hdiutil attach -imagekey diskimage-class=CRawDiskImage ios16-root.img`) and add what the build script does not do yet:
    * the GL library: build it with `tools/sweetgl/build.sh` and copy `tools/sweetgl/out/sweetgl.dylib` to `/usr/lib/sweetgl.dylib` (mode 755);
    * the stock apps: move every app from `/private/var/staged_system_apps` into `/Applications` (iOS's own first-boot install of them fails on code signing here);
    * the stock wallpapers: `tools/wallpaper-heic2png.sh MOUNTED_ROOT`.

   Then detach it, convert it with `tools/img2simg.py` and flash it with `fastboot flash userdata`. The first boot takes a few minutes longer while iOS builds its caches.

3. **Firmware:** the Adreno 530 microcode (`a530_pm4.fw`, `a530_pfp.fw`, without their 4-byte headers), the zap shader (`a530_zap.mdt` + `.b02`) and the QCA6174 Wi-Fi files (`otp30.bin`, `qwlan30.bin`, `bdwlan30.bin`, `.b80`, `.b82`) come from the phone's own `vendor` partition — `adb pull /vendor/firmware` from a booted stock OP3 ROM. They are not in this repository.

4. **Boot image:** `tools/mkadt.py ADT --oneplus3` (needs the iPhone SE 2 device tree `n104ap` from the SE2 IPSW), then
    ```
    python3 tools/mkpayload.py KERNEL ADT payload --cmdline "$ARGS" \
        --blob GPU-PM4=pm4.bin --blob GPU-PFP=pfp.bin \
        --blob GPU-ZAP-MDT=a530_zap.mdt --blob GPU-ZAP-SEG=a530_zap.b02 \
        --blob WLAN-OTP=otp30.bin --blob WLAN-FW=qwlan30.bin --blob WLAN-BDF=bdwlan30.bin \
        --blob WLAN-BDF-80=bdwlan30.b80 --blob WLAN-BDF-82=bdwlan30.b82
    WDT_SECS=0 shim/build-oneplus.sh STOCK_BOOT.img payload   # -> shim/out/oneplus3-boot.img
    fastboot boot shim/out/oneplus3-boot.img
    ```
   with the boot-args in use:
    ```
    debug=0xc serial=3 cpus=4 keepsyms=1 -noprogress sweetusb=0 rd=ufsroot0 unentitled_ios_sim_launch=1
    ignition_level=1 wdt_test=no_user_checkin ufsrw=1 rootrw=1 launchd_unsecure_cache=1 wdt=-1
    sweetfb_noconsole=1 sweetsample=- sweetnull=backboardd cs_enforcement_disable=1 sweetprof=-
    sweetgpu=8 sweetgpuclk=600 sweetddr=1804 sweetenv=backboardd:DYLD_INSERT_LIBRARIES=/usr/lib/sweetgl.dylib
    oneplus3wlan=1
    ```
   Boot-args are limited to 608 bytes; longer command lines are cut off silently. Join a network from Settings (or add `oneplus3ssid=` / `oneplus3psk=` to join at boot).

5. **Logs:** boot TWRP (`fastboot boot twrp.img`), then `tools/sweet-log-pull.sh OUT.txt`. The log will contain the OP3 probe lines from the touch and keys drivers (`SWEET TOUCH:` and `SWEET KEYS:`) — match each `TODO_VERIFY(OP3 DTB)` mark in `0185`/`0187` against the readback to confirm or correct the constants on first boot.

## Repository layout

| Path | Contents |
| --- | --- |
| `xnu/patches/` | Kernel patches, applied in order on top of xnu-8796 (`0001`-`0183` are ios-sailfish; `0184`-`0190` are this OP3 port) |
| `shim/` | The boot shim (`build-oneplus.sh`, `pixel.c` with `SWEET_ONEPLUS3` flag) |
| `tools/mkadt.py`, `tools/mkpayload.py` | Apple Device Tree generator (now with `--oneplus3` flag) and kernel payload packer |
| `tools/sweetgl/` | `sweetgl.dylib`: Mesa freedreno + libdrm/msm emulation (unchanged from sailfish) |
| `tools/gpu-shaders/`, `tools/ir3asm/` | Hand-written Adreno compute shaders (unchanged) |
| `tools/mkiosroot*.sh`, `tools/sweet-root-tweaks.py` | iOS root image builder (unchanged from sailfish — uses SE2 IPSW instead of iPhone 8) |

## Notable kernel pieces

* `bsd/dev/sweet_touch.c`: the OP3 touch driver is selected by `SWEET_ONEPLUS3` (see `0185-oneplus3-touch-rmi4.patch`). It is a near-twin of the Pixel 1's RMI4 path with different constants; the protocol body is shared.
* `bsd/dev/sweet_keys.c`: the OP3 keys driver, also selected by `SWEET_ONEPLUS3`. Unlike the Pixel 1, it does NOT map volume-down to Home — OP3 has a real hardware Home button via the touch IC's F30 function.
* `iokit/Kernel/arm/SweetFramebuffer.cpp`: the OP3 panel path reuses the Pixel 1's `startScaled()` 24bpp-to-BGRA path unchanged (same panel class, same 750x1334 logical iPhone SE2 panel presentation). The panel init DCS sequence is left to the OP3 stock bootloader.
* `bsd/dev/sweet_perf.c`: OP3 SD820 perf cluster OPP table is identical to SD821's perf cluster; `sweetboost` / `sweetturbo` behave as on the Pixel 1.

## Bring-up checklist for first boot on a real OP3

The following probe lines in the kernel log confirm each OP3-specific patch:

- `SWEET GIC: redistributor stride 0x40000` — `0079-sweet-pixel1-gic-stride` (reused; same stride as Pixel 1)
- `SWEET TOUCH: clocks on (vote=... cbcr=... rcgr=...)` — `0185` section: confirms QUP4 I2C clocked
- `SWEET TOUCH: PDT done f01@page 0 (...) f12@page ...` — `0185` section: confirms the S1302 RMI4 PDT scan succeeded
- `SWEET TOUCH: F12 layout bit N objects M` — `0185` section: F12 query 5/8 read back
- `SWEET KEYS: arb=0x2xxxxxxx pon-apid=N pon=0x.. (no Home mapping)` — `0187` section: PMIC arbiter v2 probed, PON readable, no Home mapping (unlike Pixel 1's `Home = volume down` line)
- `SWEET FB: AppleCLCD 1080x1920 stride 3240 at 0x9c000000, default surface N, presented as 750x1334, scaled to the 24 bpp panel` — `0087` / `0186` (reused + OP3 stub): framebuffer and panel scaled
- `SWEET PERF: perf cluster CBF ...` — `0190` section: perf cluster PLL voted

If any `SWEET TOUCH:` or `SWEET KEYS:` line reports a failure, the corresponding `TODO_VERIFY(OP3 DTB)` mark in the patch is the next place to look.

## Credits

* [joranv1/ios-sailfish](https://github.com/joranv1/ios-sailfish): the Pixel 1 base this port builds on.
* [dipa-studio/ios-sweet](https://github.com/dipa-studio/ios-sweet): the original XNU-on-Qualcomm port.
* [dipa-studio/ios-sweet PR #5 (A71 port)](https://github.com/dipa-studio/ios-sweet/pull/5): the template for how to structure a port PR (machine-config rename, touch/panel/keys patches, README rewrite, parent-project cleanup).
* [dipa-studio/ios-sweet PR #11 (A05s port)](https://github.com/dipa-studio/ios-sweet/pull/11): the ARMv8.0 / non-PAC machine-config pattern that the OP3 (SD820, also ARMv8.0 / non-PAC / Kryo) inherits unchanged.
* Mesa / freedreno: the open-source Adreno driver that renders iOS here.
* Apple's open-source XNU, and [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build) for building it.

iOS itself is Apple's and is not distributed here: you build the root from Apple's own IPSW.
