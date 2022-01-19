# UMPC hardware configuration for Ubuntu

Here are a couple of scripts for Ultra Mobile PCs (UMPC) such as the
[GPD Pocket](https://gpd.hk/gpdpocket), [GPD Pocket 2](https://gpd.hk/gpdpocket2),
[GPD Pocket 3](https://gpd.hk/gpdpocket3), [GPD MicroPC](https://gpd.hk/gpdmicropc),
[GPD WIN 2](https://gpd.hk/gdpwin2), [GPD P2 Max](https://www.gpd.hk/gpdp2max),
[GPD WIN Max](https://gpd.hk/gpdwinmax) and [Topjoy Falcon](https://www.kickstarter.com/projects/440069565/falcon-worlds-first-8-inch-2-in-1-laptop)
for Ubuntu users.

  * `umpc-ubuntu.sh`: install the required hardware configuration on a running Ubuntu install.
  * `umpc-ubuntu-respin.sh`: modify an existing Ubuntu .iso image with UMPC specific hardware configuration.

Ultra Mobile PCs (UMPC) have had something of a resurgence in recent years
thanks to very successful crowd funding campaigns for netbook style laptops
featuring a high resolution touch displays housed in an aluminium alloy
body. These scripts for UMPC devices are based on the excellent work by
[Hans de Goede](https://hansdegoede.livejournal.com/), [nexus511](https://apt.nexus511.net/),
[stockmind](https://github.com/stockmind/gpd-pocket-ubuntu-respin) and many
others.

![GPD Pockets](gpd-pockets.jpg "The GPD Pocket & GPD Pocket 2 running Ubuntu MATE 18.10")

## Pre-configured images

The Ubuntu MATE team offers a bespoke images for the
[GPD Pocket](https://gpd.hk/gpdpocket),
[GPD Pocket 2](https://gpd.hk/gpdpocket2),
[GPD Pocket 3](https://gpd.hk/gpdpocket3),
[GPD WIN 2](https://gpd.hk/gdpwin2),
[GPD MicroPC](https://gpd.hk/gpdmicropc),
[GPD P2 Max](https://www.gpd.hk/gpdp2max),
[GPD WIN Max](https://gpd.hk/gpdwinmax) and
[Topjoy Falcon](https://www.kickstarter.com/projects/440069565/falcon-worlds-first-8-inch-2-in-1-laptop)
that include the hardware specific tweaks to get these devices working
*"out of the box"* without any faffing about. Some models of the OneMix
Yoga devices are also supported.

  * <https://ubuntu-mate.org/download/>

## What works

The [Ubuntu MATE images for the UMPCs](https://ubuntu-mate.org/umpc/) add the following tweaks:

  * Enable **frame buffer and Xorg display rotation**.
    * Supports `modesetting` *and* `xorg-video-intel` display drivers.
  * Enable **TearFree rendering by default**.
  * Enable touch screen rotation for Xorg and Wayland.
  * Enable **scroll wheel emulation** for Xorg.
    * While holding down the **right track point button** on the Pocket, Pocket 2 & Topjoy Falcon.
    * While holding down the **centre track point button** on the MicroPC & Pocket 3.
  * Enable double size console (tty) font resolution for high resolution devices.
  * Enable **fractional scaling** for 1920x1200 displays. *(MATE Desktop only)*
    * Results in an effective resolution of 1280x800 to make the display panels easily readable.
    * Simple to toggle on/off if you want to restore full resolution.
  * **GRUB is usable post-install**.
    * GPD Pocket, WIN 2, MicroPC & TopJoy Falcon GRUB is rotated 90 degrees, but functional.
    * GPD Pocket 2 and GPD P2 Max GRUB is correctly rotated and functional.
  * GPD Pocket BRMC4356 WiFi firmware enabled by default.
  * GPD Pocket fan control kernel module enable by default.
  * GPD Pocket 3 & TopJoy Falcon **accelerometer support for automatic screen rotation**.
  * GPD WIN Max features a custom, persistent, EDID.

## Known Issues

### GPD Pocket, GPD Pocket 3, WIN 2, MicroPC, WIN Max and Topjoy Falcon

  * The GRUB menu is rotated 90 degrees on the GPD Pocket, MicroPC and Topjoy Falcon.
    * The workaround is to tilt your head.
  * The built in speaker in the GPD Pocket is mono and doesn't play audio from the right channel.
    * The workaround is to use headphones connected the 3.5mm audio jack.

### GPD Pocket 2

  * The boot menu is not displayed in the GPD Pocket 2 live media.
    * The workaround is to wait and the system will boot after a few seconds or press <kbd>Enter</kbd> to boot immediately.
    * However, **GRUB is fully functional and usable post-install**.

### GPD Pocket 3, GPD WIN 2, GPD WIN Max & Topjoy Falcon

  * The Plymouth splash screen is not correctly orientated; and for the GPD WIN Max incorrectly coloured.
    * The workaround is to not care.

## The Scripts

These scripts have been tested on [Ubuntu MATE](https://ubuntu-mate.org) 20.04.1.
All Ubuntu flavours should work although if you use Wayland your mileage may vary.

### umpc-ubuntu.sh

Install one of the Ubuntu 20.04 (or newer) flavours on a supported UMPC
device and run the following to inject the required hardware configuration.

```bash
git clone https://github.com/wimpysworld/umpc-ubuntu.git
cd umpc-ubuntu
sudo ./umpc-ubuntu.sh enable || disable
```

You must supply one of the following modes of operation

  * `enable`  : apply the UMPC hardware configuration
  * `disable` : remove the UMPC hardware configuration
  * `help`    : This help.

### umpc-ubuntu-respin.sh

```bash
git clone https://github.com/wimpysworld/umpc-ubuntu.git
cd umpc-ubuntu
```

  * Download an .iso image for one of the Ubuntu 20.04 (or newer) flavours.

```bash
sudo ./umpc-ubuntu-respin.sh -d gpd-pocket ubuntu-mate-20.04.3-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d gpd-pocket2 ubuntu-mate-20.04.3-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d gpd-pocket3 ubuntu-mate-21.10-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d gpd-micropc ubuntu-mate-20.04.3-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d gpd-p2-max ubuntu-mate-20.04.3-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d gpd-win-max ubuntu-mate-20.04.3-desktop-amd64.iso
sudo ./umpc-ubuntu-respin.sh -d topjoy-falcon ubuntu-mate-20.04.3-desktop-amd64.iso
```

A new .iso will be created that includes the additional hardware tweaks
required by the selected UMPC device.

## Accessing boot menus & BIOS

Switch the device on, immediately hold/tap the corresponding key(s).

|      Device      |      BIOS    |  Boot  Menu  |
|   -------------  | ------------ | ------------ |
| GPD Pocket       | `Fn` + `F7`  | `Fn` + `F7`  |
| GPD Pocket 2     | `Fn` + `F12` | `Fn` + `F12` |
| GPD Pocket 3     | `Fn` + `F7`  | `Fn` + `F7`  |
| GPD WIN 2(!)     |    `Del`     |    `Del`     |
| GPD MicroPC      | `Fn` + `F7`  | `Fn` + `F7`  |
| GPD P2 Max       | `Fn` + `F7`  | `Fn` + `F7`  |
| GPD WIN Max      |     `F7`     |     `F7`     |
| OneMix Yoga 2    | `Fn` + `F7`  | `Fn` + `F7`  |
| TopJoy Falcon    | `Fn` + `F2`  | `Fn` + `F12` |

  * **GPD WIN 2(!)**: Navigate to *Save & Exit* and choose the storage device you want to boot from under *Boot Override* |

## Device matrix

Please help complete this table by running the following commands from an Ubuntu Live image:

```
xrandr --query
xinput
```

|      Device      |    Monitor   | Resolution | Rotation |              Keyboard/Mouse               |          Touch Screen         | Kernel Req | Ubuntu Req |    Common     |
|   -------------  | ------------ | ---------- | -------- | ----------------------------------------- | ----------------------------- | ---------- | ---------- | ------------- |
| GPD Pocket       | DSI-1 / DSI1 | 1200x1920  | Right    | SINO WEALTH Gaming Keyboard               | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | gpd-pocket    |
| GPD Pocket 2     | eDP-1 / eDP1 | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | gpd-pocket2   |
| GPD Pocket 3     | DSI-1 / DSI1 | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | GXTP7380:00 27C6:0113         | >= 5.13    | >= 21.10   | gpd-pocket3   |
| GPD WIN 2        | eDP-1 / eDP1 | 720x1280   | Right    | HK-ZYYK-US-A1-02-00 USB Keyboard Mouse    | Goodix Capacitive TouchScreen | >= 4.18    | >= 19.04   | gpd-pocket2   |
| GPD MicroPC      | DSI-1 / DSI1 | 720x1280   | Right    | AMR-4630-XXX-0- 0-1023 USB KEYBOARD Mouse | n/a                           | >= 5.2     | >= 19.10   | gpd-micropc   |
| GPD P2 Max       | eDP-1 / eDP1 | 2560x1600  | n/a      | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | ?          | >          | gpd-p2-max    |
| GPD WIN Max      | eDP-1 / eDP1 | 800x1280   | Right    | HTIX5288:00 093A:0255 Mouse               | Goodix Capacitive TouchScreen | >= 5.4     | >= 20.04.1 | gpd-win-max   |
| OneMix Yoga      | ?            | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | ?             |
| OneMix Yoga 1s   | eDP-1 / eDP1 | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | gpd-pocket2   |
| OneMix Yoga 2    | eDP-1 / eDP1 | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | gpd-pocket2   |
| TopJoy Falcon    | DSI-1 / DSI1 | 1200x1920  | Right    | HAILUCK CO.,LTD USB KEYBOARD Mouse        | Goodix Capacitive TouchScreen | >= 4.18    | >= 18.04.2 | topjoy-falcon |
| Chuwi Minibook X | DSI-1 / DSI1 | 1200x1920  | Right    | SIPODEV USB Composite Device Mouse        | ?                             | ?          | ?          | n/a           |
