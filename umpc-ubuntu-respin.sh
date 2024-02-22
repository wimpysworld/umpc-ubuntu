#!/usr/bin/env bash

function usage() {
    echo
    echo "NAME"
    echo "    $(basename "${0}") - Apply GPD/TopJoy device modifications to an Ubuntu .iso image."
    echo
    echo "SYNOPSIS"
    echo "    $(basename "${0}") [ options ] [ ubuntu iso image ]"
    echo
    echo "OPTIONS"
    echo "    -d"
    echo "        device modifications to apply to the iso image, can be 'gpd-pocket', 'gpd-pocket2', 'gpd-pocket3', 'gpd-micropc', 'gpd-p2-max', 'gpd-win2', 'gpd-win3', 'gpd-win-max' or 'topjoy-falcon'"
    echo
    echo "    -h"
    echo "        display this help and exit"
    echo
    exit
}

# Copy file from /data to it's intended location
function inject_data() {
  local TARGET_FILE="${1}"
  local TARGET_DIR=$(dirname "${TARGET_FILE}")
  if [ -n "${2}" ] && [ -f "${2}" ]; then
    local SOURCE_FILE="${2}"
  else
    local SOURCE_FILE="data/$(basename ${TARGET_FILE})"
  fi

  if [ -f "${SOURCE_FILE}" ]; then
    echo " - Injecting ${TARGET_FILE}"
    if [ ! -d "${TARGET_DIR}" ]; then
      mkdir -p "${TARGET_DIR}"
    fi
    cp "${SOURCE_FILE}" "${TARGET_FILE}"

    # Rename the GDM3 monitors configuration
    if [[ "${TARGET_FILE}" == *"monitors.xml"* ]]; then
      mv -v "${TARGET_FILE}" "${TARGET_DIR}/monitors.xml"
    fi
  fi
}

function clean_up() {
  echo "Cleaning up..."
  echo "  - ${MNT_IN}"
  rm -rf "${MNT_IN}"
  echo "  - ${MNT_OUT}"
  rm -rf "${MNT_OUT}"
}

# Make sure we are root.
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR! You must be root to run $(basename "${0}")"
  exit 1
fi

if [ ! -f /usr/bin/xorriso ]; then
  echo "ERROR! Unable to find /usr/bin/xorriso. Installing now..."
  apt-get -y install xorriso
fi

if [ ! -f /usr/bin/unsquashfs ]; then
  echo "ERROR! Unable to find /usr/bin/unsquashfs. Installing now..."
  apt-get -y install squashfs-tools
fi


UMPC=""
OPTSTRING=d:h
while getopts ${OPTSTRING} OPT; do
    case ${OPT} in
        d) UMPC="${OPTARG}";;
        h) usage;;
        *) usage;;
    esac
done
shift "$((OPTIND - 1))"
ISO_IN="${1}"

if [ -z "${UMPC}" ]; then
    echo "ERROR! You must supply the name of the device you want to apply modifications for."
    usage
fi

case "${UMPC}" in
  gpd-pocket|gpd-pocket2|gpd-pocket3|gpd-micropc|gpd-p2-max|gpd-win2|gpd-win3|gpd-win-max|topjoy-falcon) true;;
  *) echo "ERROR! Unknown device name given."
     usage;;
esac

if [ -z "${ISO_IN}" ]; then
    echo "ERROR! You must provide the filename of an Ubuntu iso image."
    usage
fi

if [ ! -f "${ISO_IN}" ]; then
    echo "ERROR! Can not access ${ISO_IN}."
    exit
fi

ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${UMPC}\.iso/")
if [ -f "${ISO_OUT}" ]; then
  rm -f "${ISO_OUT}"
fi

MNT_IN="${HOME}/iso_in"
MNT_OUT="${HOME}/iso_out"
SQUASH_IN="${MNT_IN}/casper/filesystem.squashfs"
SQUASH_OUT="${MNT_OUT}/casper/squashfs-root"
XORG_CONF_PATH="${SQUASH_OUT}/usr/share/X11/xorg.conf.d"
INTEL_CONF="${XORG_CONF_PATH}/20-${UMPC}-intel.conf"
MODPROBE_CONF="${SQUASH_OUT}/etc/modprobe.d/alsa-${UMPC}.conf"
MONITOR_CONF="${XORG_CONF_PATH}/40-${UMPC}-monitor.conf"
MONITORS_XML="${SQUASH_OUT}/var/lib/gdm3/.config/${UMPC}-monitors.xml"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${UMPC}-trackpoint.conf"
TOUCH_RULES="${SQUASH_OUT}/etc/udev/rules.d/99-${UMPC}-touch.rules"
GRUB_DEFAULT_CONF="${SQUASH_OUT}/etc/default/grub"
GRUB_D_CONF="${SQUASH_OUT}/etc/default/grub.d/${UMPC}.cfg"
GRUB_BOOT_CONF="${MNT_OUT}/boot/grub/grub.cfg"
GRUB_LOOPBACK_CONF="${MNT_OUT}/boot/grub/loopback.cfg"
CONSOLE_CONF="${SQUASH_OUT}/etc/default/console-setup"
GSCHEMA_OVERRIDE="${SQUASH_OUT}/usr/share/glib-2.0/schemas/90-${UMPC}.gschema.override"
HWDB_CONF="${SQUASH_OUT}/etc/udev/hwdb.d/61-${UMPC}-sensor-local.hwdb"

# Copy the contents of the ISO
mkdir -p "${MNT_IN}"
mkdir -p "${MNT_OUT}"
mount -o loop "${ISO_IN}" "${MNT_IN}"
if [ $? -ne 0 ]; then
  echo "ERROR! Unable to mount ${ISO_IN}"
  clean_up
  exit 1
fi

if [ -d "${MNT_IN}/isolinux" ]; then
  ISO_BUILD="old"
  if [ ! -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
    echo "ERROR! Unable to find /usr/lib/ISOLINUX/isohdpfx.bin. Installing now..."
    apt-get -y install isolinux
  fi
else
  ISO_BUILD="new"
  if [ ! -f /usr/share/cd-boot-images-amd64/images/boot/grub/efi.img ]; then
    echo "ERROR! Unable to find /usr/share/cd-boot-images-amd64/images/boot/grub/efi.img. Installing now..."
    apt-get -y install cd-boot-images-amd64
  fi
fi

if [ -f "${MNT_IN}/.disk/info" ] && [ -f "${MNT_IN}/casper/filesystem.squashfs" ]; then
  FLAVOUR=$(cut -d' ' -f1 < "${MNT_IN}/.disk/info")
  VERSION=$(cut -d' ' -f2 < "${MNT_IN}/.disk/info")
  CODENAME=$(cut -d'"' -f2 < "${MNT_IN}/.disk/info")
  echo "Modifying ${FLAVOUR} ${VERSION} (${CODENAME}) for the ${UMPC}"

  rsync -aHAXx --delete --quiet \
    --exclude=/casper/filesystem.squashfs \
    --exclude=/casper/filesystem.squashfs.gpg \
    --exclude=/md5sum.txt \
    "${MNT_IN}/" "${MNT_OUT}/" 2>&1 >/dev/null

  # Extract the contents of the squashfs
  unsquashfs -f -d "${SQUASH_OUT}" "${SQUASH_IN}"
  umount -l "${MNT_IN}"
else
  echo "ERROR! This doesn't look like an Ubuntu iso image."
  umount -l "${MNT_IN}"
  clean_up
  exit 1
fi

# Check versions
case ${VERSION} in
  14*|16*|18*)
    echo "ERROR! Only Ubuntu 20.04 or newer is supported."
    exit 1
    ;;
esac

# Some device have require specific Ubuntu releases.
case "${UMPC}" in
  gpd-pocket3)
    # Enable Intel SNA, DRI1/3 and TearFree.
    inject_data "${INTEL_CONF}"

    case ${VERSION} in
      20*|21.04)
        echo "ERROR! GPD Pocket 3 is only supported by Ubuntu 21.10 and newer."
        exit 1
        ;;
    esac
    ;;
  gpd-win-max)
    case ${VERSION} in
      22.04*)
        GRUB_D_CONF="${SQUASH_OUT}/etc/default/grub.d/${UMPC}-new.cfg"
        echo "ERROR! GPD Win Max is only supported by Ubuntu 20.04 to 21.10."
        exit 1
        ;;
    esac
    ;;
esac

# NOTE! Do not inject this configuration anymore. The defaults are sane.
# Enable Intel SNA, DRI1/3 and TearFree.
# inject_data "${INTEL_CONF}"

# Rotate the monitor.
inject_data "${MONITOR_CONF}"
inject_data "${MONITORS_XML}"

# Scroll while holding down the right track point button
inject_data "${TRACKPOINT_CONF}"

# Apply device specific gschema overrides
inject_data "${GSCHEMA_OVERRIDE}"

# Add device specific /etc/grub.d configuration
inject_data "${GRUB_D_CONF}"


case ${UMPC} in
  gpd-pocket3)
    ;;
  *)
    # Rotate the touchscreen.
    inject_data "${TOUCH_RULES}"

    # Configure kernel modules
    inject_data "${MODPROBE_CONF}"
    ;;
esac


# Device specific tweaks
case ${UMPC} in
  gpd-pocket)
    # Add BRCM4356 firmware configuration
    inject_data "${SQUASH_OUT}/lib/firmware/brcm/brcmfmac4356-pcie.txt"

    # Frame buffer rotation
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"

    # Increase console font size
    sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

    # Display scaler
    inject_data "${SQUASH_OUT}/usr/bin/umpc-display-scaler"
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-scaler.desktop"
    inject_data "${SQUASH_OUT}/usr/share/applications/umpc-display-scaler.desktop"
    ;;
  gpd-pocket2)
    # Frame buffer rotation
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"

    # Increase console font size
    sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

    # Display scaler
    inject_data "${SQUASH_OUT}/usr/bin/umpc-display-scaler"
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-scaler.desktop"
    inject_data "${SQUASH_OUT}/usr/share/applications/umpc-display-scaler.desktop"
    ;;
  gpd-pocket3)
    # Frame buffer rotation and s2idle by default.
    # s2idle is a temporary workaround
    #  - Otherwise the screen will not turn back on after blanking if the system is busy.
    #  - This issue also affects suspend feature.
    #  - Patches are being worked on, more info here:
    #    https://ubuntu-mate.community/t/gpd-pocket-3-s3-sleep-waiting-for-kernel-fix/25053/
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"

    # Increase console font size
    sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

    # Add automatic screen rotation
    gcc -O2 "data/umpc-display-rotate.c" -o "${SQUASH_OUT}/usr/bin/umpc-display-rotate" -lm
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-rotate.desktop"
    inject_data "${HWDB_CONF}"

    # Display scaler
    inject_data "${SQUASH_OUT}/usr/bin/umpc-display-scaler"
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-scaler.desktop"
    inject_data "${SQUASH_OUT}/usr/share/applications/umpc-display-scaler.desktop"
    ;;
  gpd-p2-max)
    # Increase console font size
    sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"
    ;;
  gpd-micropc)
    # Frame buffer rotation
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"
    ;;
  gpd-win2)
    # Frame buffer rotation
    # s2idle is required to wake from suspend.
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1 video=eDP-1:panel_orientation=right_side_up mem_sleep_default=s2idle/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=eDP-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=eDP-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"
    ;;
  gpd-win3)
    # Frame buffer rotation and s2idle by default.
    # s2idle is a temporary workaround
    #  - Otherwise the screen will not turn back on after blanking if the system is busy.
    #  - This issue also affects suspend feature.
    #  - Patches are being worked on, more info here:
    #    https://ubuntu-mate.community/t/gpd-pocket-3-s3-sleep-waiting-for-kernel-fix/25053/
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle/' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up mem_sleep_default=s2idle fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"

    # Might need a workaround for the touch screen.
    # > "My touch screen does work if I "modprobe -r goodix && modprobe goodix"
    # > after login, as opposed to adding it under /etc/modules-load.d."
    # See also: https://aur.archlinux.org/packages/goodix-gpdwin3-dkms/
    ;;
  gpd-win-max)
    # Add device specific EDID on Ubuntu 21.10 are earlier
    # https://patchwork.kernel.org/project/intel-gfx/cover/20210817204329.5457-1-anisse@astier.eu/#24416791
    case "${VERSION}" in
      22*)
        sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"fbcon=rotate:1 video=eDP-1:800x1280/" "${GRUB_DEFAULT_CONF}"
        sed -i "s/quiet splash/fbcon=rotate:1 video=eDP-1:800x1280 fsck.mode=skip quiet splash/g" "${GRUB_BOOT_CONF}"
        sed -i "s/quiet splash/fbcon=rotate:1 video=eDP-1:800x1280 fsck.mode=skip quiet splash/g" "${GRUB_LOOPBACK_CONF}"
        ;;
      *)
        inject_data "${SQUASH_OUT}/usr/lib/firmware/edid/${UMPC}-edid.bin"
        sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"fbcon=rotate:1 video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin/" "${GRUB_DEFAULT_CONF}"
        sed -i "s/quiet splash/fbcon=rotate:1 video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin fsck.mode=skip quiet splash/g" "${GRUB_BOOT_CONF}"
        sed -i "s/quiet splash/fbcon=rotate:1 video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin fsck.mode=skip quiet splash/g" "${GRUB_LOOPBACK_CONF}"
        ;;
    esac
    ;;
  topjoy-falcon)
    # Frame buffer rotation
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up /' "${GRUB_DEFAULT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
    sed -i 's/quiet splash/fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"

    # Increase console font size
    sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

    # Add automatic screen rotation
    gcc -O2 "data/umpc-display-rotate.c" -o "${SQUASH_OUT}/usr/bin/umpc-display-rotate" -lm
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-rotate.desktop"
    inject_data "${HWDB_CONF}"

    # Display scaler
    inject_data "${SQUASH_OUT}/usr/bin/umpc-display-scaler"
    inject_data "${SQUASH_OUT}/etc/xdg/autostart/umpc-display-scaler.desktop"
    inject_data "${SQUASH_OUT}/usr/share/applications/umpc-display-scaler.desktop"
    ;;
  *)
    echo "ERROR! No device configuration for ${UMPC}!"
    exit 1
    ;;
esac

#echo
#echo "Modified : ${GRUB_DEFAULT_CONF}"
#cat "${GRUB_DEFAULT_CONF}"
#echo

#echo
#echo "Modified : ${GRUB_BOOT_CONF}"
#cat "${GRUB_BOOT_CONF}"
#echo

#echo
#echo "Modified : ${GRUB_LOOPBACK_CONF}"
#cat "${GRUB_LOOPBACK_CONF}"
#echo

# Update filesystem size
du -sx --block-size=1 "${SQUASH_OUT}" | cut -f1 > "${MNT_OUT}/casper/filesystem.size"

# Repack squahsfs
rm -f "${MNT_OUT}/casper/filesystem.squashfs" 2>/dev/null
mksquashfs "${SQUASH_OUT}" "${MNT_OUT}/casper/filesystem.squashfs"
echo "Cleaning up..."
echo "  - ${SQUASH_OUT}"
rm -rf "${SQUASH_OUT}"
sync

# Collect md5sums
find "${MNT_OUT}" -type f -print0 | xargs -0 md5sum | sed 's|'"${MNT_OUT}"'|\.|g' > "${MNT_OUT}/md5sum.txt"

VOL_ID=$(echo "${FLAVOUR}-${VERSION}-${UMPC}" | cut -c1-31)
rm -f "${ISO_OUT}" 2>/dev/null

# Reference for new iso build:
#  - https://bugs.launchpad.net/ubuntu-cdimage/+bug/1886148
#  - From https://bugs.launchpad.net/ubuntu-cdimage/+bug/1886148/comments/195
case ${ISO_BUILD} in
  old)
  xorriso \
  -as mkisofs \
  -r \
  -checksum_algorithm_iso md5,sha1 \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -J \
  -l \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -isohybrid-apm-hfsplus \
  -volid "${VOL_ID}" \
  -o "${ISO_OUT}" "${MNT_OUT}/";;
  *)
  xorriso \
  -as mkisofs \
  -r \
  -checksum_algorithm_iso md5,sha1 \
  -J -joliet-long \
  -l \
  -b boot/grub/i386-pc/eltorito.img -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --grub2-boot-info \
  --grub2-mbr /usr/share/cd-boot-images-amd64/images/boot/grub/i386-pc/boot_hybrid.img \
  -append_partition 2 0xef /usr/share/cd-boot-images-amd64/images/boot/grub/efi.img \
  -appended_part_as_gpt -eltorito-alt-boot -e --interval\:appended_partition_2\:all\:\: -no-emul-boot \
  -partition_offset 16 /usr/share/cd-boot-images-amd64/tree \
  -V "${VOL_ID}" \
  -o "${ISO_OUT}" "${MNT_OUT}/";;
esac
chown -v "${SUDO_USER}":"${SUDO_USER}" "${ISO_OUT}"
clean_up
