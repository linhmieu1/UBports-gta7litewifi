<div align="center">

```
  __  __  _____  _          __ _  ___
 |  \/  ||  _  || |        / /| |/ __|
 | \  / || | | || |  ___  / /_| | |_
 | |\/| || | | || | / _ \| '_ \ \___ \
 | |  | |\ \_/ /| ||  __/| (_) |___/ /
 |_|  |_| \___/ |_| \___| \___/|____/
```

**Mobile-Optimized Workspace Interface Shell**

*Samsung DeX-inspired Desktop Environment*
*Built on UKUI — Qt fork of MATE*

</div>

---

## What is MOWIS?

MOWIS is a desktop environment for Arch Linux (and other distributions) that
brings the **Samsung DeX** desktop experience to your PC. It uses
[UKUI](https://www.ukui.org/) as its engine — a modern Qt-based fork of the
MATE Desktop Environment — and layers a DeX-inspired theme and configuration
on top.

### Key features

- **DeX-style top taskbar** via `ukui-panel` positioned at the top
- **Frosted glass effects** via `picom` (dual-kawase blur + shadows)
- **Snap window management** — `Super+←/→` snaps windows 50/50
- **4 workspaces** switchable with `Super+1-4`
- **Dark theme** — `ukui-black` + Papirus-Dark icons + Kvantum Qt theme
- **DeX App Launcher** via Rofi with custom MOWIS theme
- **System widget** showing CPU/RAM/Battery/Network (Python + GTK3)
- **Qt + GTK unified dark** look across all applications

---

## Components

### Core (mowis-desktop-environment-core)
| Component | Role |
|-----------|------|
| `ukui-session-manager` | Session management |
| `ukui-kwin` / `ukwm` | Window manager |
| `ukui-panel` | Top taskbar (DeX style) |
| `ukui-settings-daemon` | Settings daemon |
| `ukui-control-center` | System settings |
| `ukui-menu` | Application menu |
| `peony` | File manager |
| `ukui-sidebar` | Sidebar / Action center |
| `picom` | Compositor (blur + shadows) |
| `rofi` | App launcher (DeX drawer) |
| `dunst` | Notification daemon |
| `kvantum` | Qt theme engine |
| `papirus-icon-theme` | Icon theme |

### Optional (mowis-desktop-environment-extras)
- `ukui-system-monitor`
- `ukui-biometric-auth`
- `ukui-screensaver`
- `ukui-power-manager`
- `dconf-editor`
- `gnome-keyring`

---

## Install

### Arch Linux / CachyOS (recommended)

```bash
# 1. Clone this repo
git clone https://github.com/mowis-de/mowis-desktop-environment.git
cd mowis-desktop-environment

# 2. Run install script
sudo bash install-arch.sh

# 3. Reboot and select "MOWIS Desktop" at SDDM/LightDM
sudo reboot
```

### Ubuntu / Debian

```bash
sudo apt install mowis-desktop-environment
```

*(Or build from source with `dpkg-buildpackage -b --no-sign`)*

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Super + R` | App Launcher (Rofi) |
| `Super + E` | File Manager (Peony) |
| `Super + D` | Show/Hide Desktop |
| `Super + L` | Lock Screen |
| `Super + ←` | Snap window left 50% |
| `Super + →` | Snap window right 50% |
| `Super + ↑` | Maximize window |
| `Super + ↓` | Restore window |
| `Super + 1-4` | Switch workspace |
| `Super + Shift + 1-4` | Move window to workspace |
| `Alt + F4` | Close window |
| `Alt + Tab` | Switch windows |
| `Print` | Screenshot |

---

## GSettings Defaults

MOWIS ships `mowis.gschema.override` which sets DeX-style defaults for:

- `org.mate.interface` — fonts, GTK theme
- `org.gnome.desktop.wm.preferences` — titlebar, button layout
- `org.gnome.desktop.wm.keybindings` — all DeX shortcuts
- `org.mate.Marco.*` — snap tiling, workspace switching
- `org.ukui.*` — UKUI-specific theme and panel settings
- `org.mate.background` — dark background defaults
- `org.gnome.desktop.privacy` — telemetry off by default

---

## Project Structure

```
mowis-desktop-environment/
├── debian/
│   ├── changelog                  ← Version history
│   ├── control                    ← Package dependencies
│   ├── copyright                  ← License info
│   ├── rules                      ← Build rules
│   ├── source/format
│   └── mowis.gschema.override     ← DeX GSettings defaults ★
└── README.md
```

---

## Upstream

MOWIS is a fork and theme layer on top of [UKUI](https://github.com/ukui/ukui-desktop-environment).
All UKUI components are used as-is; MOWIS only changes:
- Default GSettings values (this repo)
- Theme/compositor configuration
- Session management scripts
- Branding

---

## License

GPL-2.0-or-later — see [debian/copyright](debian/copyright)

MOWIS Project — inspired by Samsung DeX
