#!/usr/bin/env bash

# Make sure we are root.
if [ $(id -u) -ne 0 ]; then
  echo "ERROR! You must be root to run $(basename $0)"
  exit 1
fi

if [ ! -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
  echo "ERROR! Unable to find /usr/lib/ISOLINUX/isohdpfx.bin. Please 'apt install isolinux'"
  exit 1
fi

if [ ! -f /usr/bin/xorriso ]; then
  echo "ERROR! Unable to find /usr/bin/xorriso. Please 'apt install xorriso'"
  exit 1
fi

# Set to either "gpd-pocket" or "gpd-pocket2"
GPD="gpd-pocket2"
ISO_IN="ubuntu-mate-18.04.2-desktop-amd64.iso"
ISO_VER=$(echo ${ISO_IN} | cut -d'-' -f3)
ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${GPD}\.iso/")
MNT_IN="${HOME}/iso_in"
MNT_OUT="${HOME}/iso_out"
SQUASH_IN="${MNT_IN}/casper/filesystem.squashfs"
SQUASH_OUT="${MNT_OUT}/casper/squashfs-root"
XORG_CONF_PATH="${SQUASH_OUT}/usr/share/X11/xorg.conf.d"
INTEL_CONF="${XORG_CONF_PATH}/20-${GPD}-intel.conf"
MONITOR_CONF="${XORG_CONF_PATH}/40-${GPD}-monitor.conf"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${GPD}-trackpoint.conf"
TOUCH_CONF="${XORG_CONF_PATH}/81-${GPD}-touchscreen.conf"
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
  local SOURCE_FILE="data/$(basename ${TARGET_FILE})"

  echo " - Injecting ${TARGET_FILE}"

  if [ ! -d "${TARGET_DIR}" ]; then
    mkdir -p "${TARGET_DIR}"
  fi
  
  if [ -f "${SOURCE_FILE}" ]; then
    cp "${SOURCE_FILE}" "${TARGET_FILE}"
  fi
}

# Copy the contents of the ISO
mkdir -p ${MNT_IN}
mkdir -p ${MNT_OUT}
mount -o loop "${ISO_IN}" "${MNT_IN}"
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

# Rotate the monitor.
  cat << MONITOR > "${MONITOR_CONF}"
# GPD Pocket
Section "Monitor"
  Identifier "DSI-1"
  Option     "Rotate"  "right"
EndSection

# GPD Pocket2
Section "Monitor"
  Identifier "eDP-1"
  Option     "Rotate"  "right"
EndSection
MONITOR

# Rotate the touchscreen.
cat << TOUCHSCREEN > "${TOUCH_CONF}"
Section "InputClass"
  Identifier   "calibration"
  MatchProduct "Goodix Capacitive TouchScreen"
  Option       "TransformationMatrix"  "0 1 0 -1 0 1 0 0 1"
EndSection
TOUCHSCREEN


# Scale up the primary display to increase readability.
cat << 'XRANDR_SCRIPT' > ${SQUASH_OUT}/usr/bin/${XRANDR_SCRIPT}
#!/usr/bin/env bash

PRIMARY_RESOLUTION=$(xrandr | grep "connected primary" | cut -d' ' -f4 | cut -d'+' -f1 | sed 's/ //g')
if [ "${PRIMARY_RESOLUTION}" == "1920x1200" ]; then
  PRIMARY_DISPLAY=$(xrandr | grep "connected primary" | cut -d' ' -f1 | sed 's/ //g')
  xrandr --output ${PRIMARY_DISPLAY} --scale 0.64x0.64
fi
XRANDR_SCRIPT
chmod +x ${SQUASH_OUT}/usr/bin/${XRANDR_SCRIPT}

cat << XRANDR_DESKTOP > "${XRANDR_DESKTOP}"
[Desktop Entry]
Name=GPD Pocket Display Scaler
Exec=${XRANDR_SCRIPT}
Icon=user-desktop
Terminal=false
Type=Application
Categories=GTK;Settings;
StartupNotify=false
OnlyShowIn=MATE;
NoDisplay=true
Comment=Scale up the internal display on the GPD Pocket. Disable this Startup Program and log out to restore the native resolution.
XRANDR_DESKTOP

# Rotate the framebuffer
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="i915.fastboot=1 fbcon=rotate:1 quiet/' "${GRUB_DEFAULT_CONF}"
sed -i 's/#GRUB_GFXMODE="480x640/GRUB_GFXMODE=1200x1920/' "${GRUB_DEFAULT_CONF}"
sed -i 's/quiet splash/i915.fastboot=1 fbcon=rotate:1 quiet splash/g' "${GRUB_BOOT_CONF}"
#sed -i 's/#GRUB_GFXMODE="480x640/GRUB_GFXMODE=1200x1920/' "${GRUB_BOOT_CONF}

# Increase tty font size
sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

# Add BRCM4356 firmware configuration
cat << 'BRCM4356' > ${BRCM4356_CONF}
# Sample variables file for BCM94356Z NGFF 22x30mm iPA, iLNA board with PCIe for production package
NVRAMRev=$Rev: 492104 $
#4356 chip = 4354 A2 chip
sromrev=11
boardrev=0x1102
boardtype=0x073e
boardflags=0x02400201
#0x2000 enable 2G spur WAR
boardflags2=0x00802000
boardflags3=0x0000000a
#boardflags3 0x00000100 /* to read swctrlmap from nvram*/
#define BFL3_5G_SPUR_WAR   0x00080000   /* enable spur WAR in 5G band */
#define BFL3_AvVim   0x40000000   /* load AvVim from nvram */
macaddr=00:90:4c:1a:10:01
ccode=X2
regrev=205
antswitch=0
pdgain5g=4
pdgain2g=4
tworangetssi2g=0
tworangetssi5g=0
paprdis=0
femctrl=10
vendid=0x14e4
devid=0x43ec
manfid=0x2d0
#prodid=0x052e
nocrc=1
otpimagesize=502
xtalfreq=37400
rxgains2gelnagaina0=0
rxgains2gtrisoa0=7
rxgains2gtrelnabypa0=0
rxgains5gelnagaina0=0
rxgains5gtrisoa0=11
rxgains5gtrelnabypa0=0
rxgains5gmelnagaina0=0
rxgains5gmtrisoa0=13
rxgains5gmtrelnabypa0=0
rxgains5ghelnagaina0=0
rxgains5ghtrisoa0=12
rxgains5ghtrelnabypa0=0
rxgains2gelnagaina1=0
rxgains2gtrisoa1=7
rxgains2gtrelnabypa1=0
rxgains5gelnagaina1=0
rxgains5gtrisoa1=10
rxgains5gtrelnabypa1=0
rxgains5gmelnagaina1=0
rxgains5gmtrisoa1=11
rxgains5gmtrelnabypa1=0
rxgains5ghelnagaina1=0
rxgains5ghtrisoa1=11
rxgains5ghtrelnabypa1=0
rxchain=3
txchain=3
aa2g=3
aa5g=3
agbg0=2
agbg1=2
aga0=2
aga1=2
tssipos2g=1
extpagain2g=2
tssipos5g=1
extpagain5g=2
tempthresh=255
tempoffset=255
rawtempsense=0x1ff
pa2ga0=-147,6192,-705
pa2ga1=-161,6041,-701
pa5ga0=-194,6069,-739,-188,6137,-743,-185,5931,-725,-171,5898,-715
pa5ga1=-190,6248,-757,-190,6275,-759,-190,6225,-757,-184,6131,-746
subband5gver=0x4
pdoffsetcckma0=0x4
pdoffsetcckma1=0x4
pdoffset40ma0=0x0000
pdoffset80ma0=0x0000
pdoffset40ma1=0x0000
pdoffset80ma1=0x0000
maxp2ga0=76
maxp5ga0=74,74,74,74
maxp2ga1=76
maxp5ga1=74,74,74,74
cckbw202gpo=0x0000
cckbw20ul2gpo=0x0000
mcsbw202gpo=0x99644422
mcsbw402gpo=0x99644422
dot11agofdmhrbw202gpo=0x6666
ofdmlrbw202gpo=0x0022
mcsbw205glpo=0x88766663
mcsbw405glpo=0x88666663
mcsbw805glpo=0xbb666665
mcsbw205gmpo=0xd8666663
mcsbw405gmpo=0x88666663
mcsbw805gmpo=0xcc666665
mcsbw205ghpo=0xdc666663
mcsbw405ghpo=0xaa666663
mcsbw805ghpo=0xdd666665
mcslr5glpo=0x0000
mcslr5gmpo=0x0000
mcslr5ghpo=0x0000
sb20in40hrpo=0x0
sb20in80and160hr5glpo=0x0
sb40and80hr5glpo=0x0
sb20in80and160hr5gmpo=0x0
sb40and80hr5gmpo=0x0
sb20in80and160hr5ghpo=0x0
sb40and80hr5ghpo=0x0
sb20in40lrpo=0x0
sb20in80and160lr5glpo=0x0
sb40and80lr5glpo=0x0
sb20in80and160lr5gmpo=0x0
sb40and80lr5gmpo=0x0
sb20in80and160lr5ghpo=0x0
sb40and80lr5ghpo=0x0
dot11agduphrpo=0x0
dot11agduplrpo=0x0
phycal_tempdelta=255
temps_period=15
temps_hysteresis=15
rssicorrnorm_c0=4,4
rssicorrnorm_c1=4,4
rssicorrnorm5g_c0=1,2,3,1,2,3,6,6,8,6,6,8
rssicorrnorm5g_c1=1,2,3,2,2,2,7,7,8,7,7,8
BRCM4356

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
  -volid "${GPD} ${ISO_VER}" \
  -o "${ISO_OUT}" "${MNT_OUT}/"

# Clean up
echo "Cleaning up..."
echo "  - ${MNT_IN}"
rm -rf "${MNT_IN}"
echo "  - ${MNT_OUT}"
rm -rf "${MNT_OUT}"