# Ubuntu Touch for Samsung Galaxy Tab A7 Lite (gta7litewifi)

This repository contains the device-specific configuration files to port Ubuntu Touch (Focal/Jammy) to the Samsung Galaxy Tab A7 Lite, based on Halium 12.

## Device Specifications

| Feature       | Details                                         |
| ------------- | ----------------------------------------------- |
| SoC           | MediaTek MT8768 (Helio P22T)                    |
| GPU           | PowerVR Rogue GE8320                            |
| RAM           | 3GB / 4GB                                       |
| Display       | 800 x 1340 pixels, 5:3 ratio                    |
| Model         | SM-T220 (Wi-Fi)                                 |
| Android Base  | Android 11 / 12                                 |

## Current Status

**Current Stage:** Work in Progress (Booting to Spinner/Logo)

- [x] Kernel compiles and boots.
- [x] Android Container starts (LXC).
- [x] Basic Udev rules applied for MTK.
- [ ] Mir/Lomiri (Currently crashing with Signal 6).
- [ ] Touchscreen (Detected, but needs testing in UI).
- [ ] Hardware Acceleration (PowerVR issues).
- [ ] WiFi/Bluetooth.

## Known Issues & Workarounds

### 1. Mir/Compositor Crash
The system currently terminates with `signal 6` in `unity-system-compositor`. This is likely due to the PowerVR GPU memory allocation or missing EGL links. 
- **Status:** Investigating `pvr_sync` permissions and `libhybris` compatibility.

### 2. Mount Point Errors
Previously, the system had issues mounting `/android/prism` and `/android/optics` due to a read-only rootfs. 
- **Fix:** Added `mount -o remount,rw /` in `mount-android.conf`.
