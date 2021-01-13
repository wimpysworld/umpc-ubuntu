#!/usr/bin/env bash

function usage() {
    echo
    echo "NAME"
    echo "    $(basename ${0}) - Apply GPD/TopJoy device modifications to an Ubuntu .iso image."
    echo
    echo "SYNOPSIS"
    echo "    $(basename ${0}) [ options ] [ ubuntu iso image ]"
    echo
    echo "OPTIONS"
    echo "    -d"
    echo "        device modifications to apply to the iso image, can be 'gpd-pocket', 'gpd-pocket2', 'gpd-micropc', 'gpd-p2-max', 'gpd-win-max' or 'topjoy-falcon'"
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

  echo " - Injecting ${TARGET_FILE}"

  if [ ! -d "${TARGET_DIR}" ]; then
    mkdir -p "${TARGET_DIR}"
  fi

  if [ -f "${SOURCE_FILE}" ]; then
    cp "${SOURCE_FILE}" "${TARGET_FILE}"
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
if [ $(id -u) -ne 0 ]; then
  echo "ERROR! You must be root to run $(basename $0)"
  exit 1
fi

if [ ! -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
  echo "ERROR! Unable to find /usr/lib/ISOLINUX/isohdpfx.bin. Installing now..."
  apt -y install isolinux
fi

if [ ! -f /usr/bin/xorriso ]; then
  echo "ERROR! Unable to find /usr/bin/xorriso. Installing now..."
  apt -y install xorriso
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
shift "$(( $OPTIND - 1 ))"
ISO_IN="${@}"

if [ -z "${UMPC}" ]; then
    echo "ERROR! You must supply the name of the device you want to apply modifications for."
    usage
elif [ "${UMPC}" != "gpd-pocket" ] && [ "${UMPC}" != "gpd-pocket2" ] && [ "${UMPC}" != "gpd-micropc" ] && [ "${UMPC}" != "gpd-p2-max" ] && [ "${UMPC}" != "gpd-win-max" ] && [ "${UMPC}" != "topjoy-falcon" ]; then
    echo "ERROR! Unknown device name given."
    usage
fi

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
MONITOR_CONF="${XORG_CONF_PATH}/40-${UMPC}-monitor.conf"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${UMPC}-trackpoint.conf"
TOUCH_RULES="${SQUASH_OUT}/etc/udev/rules.d/99-${UMPC}-touch.rules"
BRCM4356_CONF="${SQUASH_OUT}/lib/firmware/brcm/brcmfmac4356-pcie.txt"
GRUB_DEFAULT_CONF="${SQUASH_OUT}/etc/default/grub"
GRUB_D_CONF="${SQUASH_OUT}/etc/default/grub.d/${UMPC}.cfg"
GRUB_BOOT_CONF="${MNT_OUT}/boot/grub/grub.cfg"
GRUB_LOOPBACK_CONF="${MNT_OUT}/boot/grub/loopback.cfg"
CONSOLE_CONF="${SQUASH_OUT}/etc/default/console-setup"
GSCHEMA_OVERRIDE="${SQUASH_OUT}/usr/share/glib-2.0/schemas/90-${UMPC}.gschema.override"
EDID="${SQUASH_OUT}/usr/lib/firmware/edid/${UMPC}-edid.bin"

# Copy the contents of the ISO
mkdir -p ${MNT_IN}
mkdir -p ${MNT_OUT}
mount -o loop "${ISO_IN}" "${MNT_IN}"
if [ $? -ne 0 ]; then
  echo "ERROR! Unable to mount ${ISO_IN}"
  clean_up
  exit 1
fi

if [ -f "${MNT_IN}/README.diskdefines" ] && [ -f "${MNT_IN}/casper/filesystem.squashfs" ]; then
  FLAVOUR=$(head -n1 ${MNT_IN}/README.diskdefines | cut -d' ' -f4)
  VERSION=$(head -n1 ${MNT_IN}/README.diskdefines | cut -d' ' -f5)
  QUALITY=$(head -n1 ${MNT_IN}/README.diskdefines | cut -d'-' -f3 | sed 's/amd64//'g | sed 's/ //g')
  CODENAME=$(head -n1 ${MNT_IN}/README.diskdefines | cut -d'"' -f2)
  echo "Modifying ${FLAVOUR} ${VERSION} ${QUALITY} (${CODENAME}) for the ${UMPC}"

  rsync -aHAXx --delete \
    --exclude=/casper/filesystem.squashfs \
    --exclude=/casper/filesystem.squashfs.gpg \
    --exclude=/md5sum.txt \
    "${MNT_IN}/" "${MNT_OUT}/"

  # Extract the contents of the squashfs
  cd "${MNT_OUT}/casper" || return
  unsquashfs "${SQUASH_IN}"
  cd - || return
  umount -l "${MNT_IN}"
else
  echo "ERROR! This doesn't look like an Ubuntu iso image."
  umount -l "${MNT_IN}"
  clean_up
  exit 1
fi

# Enable Intel SNA, DRI3 and TearFree.
inject_data "${INTEL_CONF}"

# Rotate the monitor.
inject_data "${MONITOR_CONF}"

# Scroll while holding down the right track point button
inject_data "${TRACKPOINT_CONF}"

# Rotate the touchscreen.
inject_data "${TOUCH_RULES}"

# Apply device specific gschema overrides
inject_data "${GSCHEMA_OVERRIDE}"

# Add device specific EDID
inject_data "${EDID}"

# Add device specific /etc/grub.d configuration
inject_data "${GRUB_D_CONF}"

# Add BRCM4356 firmware configuration
if [ "${UMPC}" == "gpd-pocket" ]; then
  inject_data "${BRCM4356_CONF}"
fi

# Rotate the framebuffer
if  [ "${UMPC}" == "gpd-win-max" ]; then
  sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin fbcon=rotate:1/" "${GRUB_DEFAULT_CONF}"
  sed -i "s/quiet splash/video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin fbcon=rotate:1 fsck.mode=skip quiet splash/g" "${GRUB_BOOT_CONF}"
  sed -i "s/quiet splash/video=eDP-1:800x1280 drm.edid_firmware=eDP-1:edid\/${UMPC}-edid.bin fbcon=rotate:1 fsck.mode=skip quiet splash/g" "${GRUB_LOOPBACK_CONF}"
else
  sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="video=efifb fbcon=rotate:1/' "${GRUB_DEFAULT_CONF}"
  sed -i 's/quiet splash/video=efifb fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_BOOT_CONF}"
  sed -i 's/quiet splash/video=efifb fbcon=rotate:1 fsck.mode=skip quiet splash/g' "${GRUB_LOOPBACK_CONF}"
fi
if [ "${UMPC}" == "gpd-pocket2" ]; then
  grep -qxF 'GRUB_GFXMODE=1200x1920x32' "${GRUB_DEFAULT_CONF}" || echo 'GRUB_GFXMODE=1200x1920x32' >> "${GRUB_DEFAULT_CONF}"
fi

echo
echo "Modified : ${GRUB_DEFAULT_CONF}"
cat "${GRUB_DEFAULT_CONF}"
echo

echo
echo "Modified : ${GRUB_BOOT_CONF}"
cat "${GRUB_BOOT_CONF}"
echo

echo
echo "Modified : ${GRUB_LOOPBACK_CONF}"
cat "${GRUB_LOOPBACK_CONF}"
echo

# Increase tty font size
sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

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
cd "${MNT_OUT}" || exit
find . -type f -print0 | xargs -0 md5sum >> "${MNT_OUT}/md5sum.txt"
cd - || exit

VOL_ID=$(echo ${FLAVOUR} ${VERSION} ${UMPC} | cut -c1-31)
rm -f "${ISO_OUT}" 2>/dev/null
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
  -o "${ISO_OUT}" "${MNT_OUT}/"

# TODO: Does xorriso need updating for 20.10 onward?
#https://bugs.launchpad.net/ubuntu-cdimage/+bug/1886148
#From https://bugs.launchpad.net/ubuntu-cdimage/+bug/1886148/comments/195
#xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1 -V Ubuntu\ 20.10\ amd64 -o /srv/cdimage.ubuntu.com/scratch/ubuntu/groovy/daily-live/debian-cd/amd64/groovy-desktop-amd64.raw -J -joliet-long -l -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info --grub2-mbr cd-boot-images/usr/share/cd-boot-images-amd64/images/boot/grub/i386-pc/boot_hybrid.img -append_partition 2 0xef cd-boot-images/usr/share/cd-boot-images-amd64/images/boot/grub/efi.img -appended_part_as_gpt -eltorito-alt-boot -e --interval\:appended_partition_2\:all\:\: -no-emul-boot -partition_offset 16 cd-boot-images/usr/share/cd-boot-images-amd64/tree CD1



chown -v "${SUDO_USER}":"${SUDO_USER}" "${ISO_OUT}"
clean_up
