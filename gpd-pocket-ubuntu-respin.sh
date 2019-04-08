#!/usr/bin/env bash

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

# Set to either "gpd-pocket" or "gpd-pocket2"
GPD="gpd-pocket2"
ISO_IN="ubuntu-mate-18.04.2-desktop-amd64.iso"
ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${GPD}\.iso/")
if [ -f "${ISO_OUT}" ]; then
  rm -f "${ISO_OUT}"
fi

MNT_IN="${HOME}/iso_in"
MNT_OUT="${HOME}/iso_out"
SQUASH_IN="${MNT_IN}/casper/filesystem.squashfs"
SQUASH_OUT="${MNT_OUT}/casper/squashfs-root"
XORG_CONF_PATH="${SQUASH_OUT}/usr/share/X11/xorg.conf.d"
INTEL_CONF="${XORG_CONF_PATH}/20-${GPD}-intel.conf"
MONITOR_CONF="${XORG_CONF_PATH}/40-${GPD}-monitor.conf"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${GPD}-trackpoint.conf"
TOUCH_RULES="${SQUASH_OUT}/etc/udev/rules.d/99-${GPD}-touch.rules"
BRCM4356_CONF="${SQUASH_OUT}/lib/firmware/brcm/brcmfmac4356-pcie.txt"
GRUB_DEFAULT_CONF="${SQUASH_OUT}/etc/default/grub"
GRUB_BOOT_CONF="${MNT_OUT}/boot/grub/grub.cfg"
CONSOLE_CONF="${SQUASH_OUT}/etc/default/console-setup"
XRANDR_SCRIPT="${SQUASH_OUT}/usr/bin/gpd-display-scaler"
XRANDR_DESKTOP="${SQUASH_OUT}/etc/xdg/autostart/gpd-display-scaler.desktop"

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
  CODENAME=$(head -n1 ${MNT_IN}/README.diskdefines | cut -d'"' -f2)
  echo "Modifying ${FLAVOUR} ${VERSION} (${CODENAME}) for the ${GPD}"

  rsync -aHAXx --delete \
    --exclude=/casper/filesystem.squashfs \
    --exclude=/casper/filesystem.squashfs.gpg \
    --exclude=/md5sum.txt \
    "${MNT_IN}/" "${MNT_OUT}/"

  # Extract the contents of the squashfs
  cd "${MNT_OUT}/casper"
  unsquashfs "${SQUASH_IN}"
  cd -
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

# Scale up the primary display to increase readability.
inject_data "${XRANDR_SCRIPT}"
inject_data "${XRANDR_DESKTOP}"

# Add BRCM4356 firmware configuration
if [ "${GPD}" == "gpd-pocket" ]; then
  inject_data "${BRCM4356_CONF}"
fi

# Rotate the framebuffer
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="video=efifb fbcon=rotate:1 quiet/' "${GRUB_DEFAULT_CONF}"
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="video=efifb fbcon=rotate:1"/' "${GRUB_DEFAULT_CONF}"
if [ "${GPD}" == "gpd-pocket2" ]; then
  grep -qxF 'GRUB_GFXMODE=1200x1920x32' "${GRUB_DEFAULT_CONF}" || echo 'GRUB_GFXMODE=1200x1920x32' >> "${GRUB_DEFAULT_CONF}"
fi
sed -i 's/quiet splash/video=efifb fbcon=rotate:1 quiet splash/g' "${GRUB_BOOT_CONF}"

echo
echo "Modified : ${GRUB_DEFAULT_CONF}"
cat "${GRUB_DEFAULT_CONF}"
echo

echo
echo "Modified : ${GRUB_BOOT_CONF}"
cat "${GRUB_BOOT_CONF}"
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
cd "${MNT_OUT}"
find . -type f -print0 | xargs -0 md5sum >> "${MNT_OUT}/md5sum.txt"
cd -

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
  -volid "${FLAVOUR} ${VERSION} ${GPD}" \
  -o "${ISO_OUT}" "${MNT_OUT}/"

clean_up