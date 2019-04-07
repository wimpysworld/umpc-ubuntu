#!/usr/bin/env bash

# Set to either "gpd-pocket" or "gpd-pocket2"
GPD="gpd-pocket2"
XORG_CONF_PATH="/usr/share/X11/xorg.conf.d"
INTEL_CONF="${XORG_CONF_PATH}/20-${GPD}-intel.conf"
MONITOR_CONF="${XORG_CONF_PATH}/40-${GPD}-monitor.conf"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${GPD}-trackpoint.conf"
TOUCH_RULES="/etc/udev/rules.d/99-gpd-touch.rules"
BRCM4356_CONF="/lib/firmware/brcm/brcmfmac4356-pcie.txt"
GRUB_DEFAULT_CONF="/etc/default/grub"
CONSOLE_CONF="/etc/default/console-setup"
XRANDR_SCRIPT="/usr/bin/gpd-display-scaler"
XRANDR_DESKTOP="/etc/xdg/autostart/gpd-display-scaler.desktop"

# Copy file from /data to it's intended location
function inject_data() {
  local TARGET_FILE="${1}"
  local TARGET_DIR=$(dirname "${TARGET_FILE}")
  local SOURCE_FILE="data/$(basename ${TARGET_FILE})"

  if [ ! -d "${TARGET_DIR}" ]; then
    mkdir -p "${TARGET_DIR}"
  fi
  
  if [ -f "${SOURCE_FILE}" ]; then
    cp "${SOURCE_FILE}" "${TARGET_FILE}"
  fi
}

function enable_gpd_pocket_config() {
  # Enable Intel SNA, DRI3 and TearFree.
  inject_data "${INTEL_CONF}"

  # Rotate the monitor.
  inject_data "${MONITOR_CONF}"

  # Scroll while holding down the right track point button
  inject_data "${TRACKPOINT_CONF}"

  # Rotate the touchscreen.
  inject_data "${TOUCH_RULES}"
  # Reload udev rules
  udevadm control --reload-rules
  udevadm trigger

  # Scale up the primary display to increase readability.
  inject_data "${XRANDR_SCRIPT}"
  inject_data "${XRANDR_DESKTOP}"

  # Add BRCM4356 firmware configuration
  if [ "${GPD}" == "gpd-pocket" ]; then
    inject_data "${BRCM4356_CONF}"
    # Reload the brcmfmac kernel module
    modprobe -r brcmfmac
    modprobe brcmfmac
  fi

  # Rotate the framebuffer
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="video=efifb fbcon=rotate:1 quiet/' "${GRUB_DEFAULT_CONF}"
  sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="video=efifb fbcon=rotate:1"/' "${GRUB_DEFAULT_CONF}"
  if [ "${GPD_POCKET}" == "gpd-pocket2" ]; then
    grep -qxF 'GRUB_GFXMODE=1200x1920x32' "${GRUB_DEFAULT_CONF}" || echo 'GRUB_GFXMODE=1200x1920x32' >> "${GRUB_DEFAULT_CONF}"
  fi
  update-grub

  # Increase tty font size
  sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

  echo "GPD Pocket hardware configuration is applied. Please reboot to complete the setup."
}

function disable_gpd_pocket_config() {
  # Remove the GPD Pocket hardware configuration
  for CONFIG in ${MONITOR_CONF} ${TOUCH_CONF} ${BRCM4356_CONF} ${XRANDR_SCRIPT} ${XRANDR_DESKTOP}; do
    if [ -f "${CONFIG}" ]; then
      rm -fv "${CONFIG}"
    fi
  done

  # Remove the framebuffer rotation
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="video=efifb fbcon=rotate:1 quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet/' "${GRUB_DEFAULT_CONF}"
  sed -i 's/GRUB_CMDLINE_LINUX="video=efifb fbcon=rotate:1"/GRUB_CMDLINE_LINUX=""/' "${GRUB_DEFAULT_CONF}"
  sed -i 's/GRUB_GFXMODE=1200x1920x32/d' "${GRUB_DEFAULT_CONF}"
  update-grub

  # Restore tty font size
  sed -i 's/FONTSIZE=16x32"/FONTSIZE="8x16"/' "${CONSOLE_CONF}"

  echo "GPD Pocket hardware configuration is removed. Please reboot to complete the setup."
}

function usage() {
    echo
    echo "Usage"
    echo "  ${0} enable || disable"
    echo ""
    echo "You must supply one of the following modes of operation"
    echo "  enable  : apply the ${MODEL} hardware configuration"
    echo "  disable : remove the ${MODEL} hardware configuration"
    echo "  help    : This help."
    echo
    exit 1
}

# Make sure we are not running on Wayland
if [ "${XDG_SESSION_TYPE}" == "wayland" ]; then
  echo "ERROR! This script is only designed to configure Xorg (X11). Please choose an alternative desktop session that uses Xorg (X11)."
  exit 1
fi

# Make sure we are root.
if [ $(id -u) -ne 0 ]; then
  echo "ERROR! You must be root to run $(basename $0)"
  exit 1
fi

# Display usage instructions if we've not been given an action. If an action
# has been provided store it in lowercase.
if [ -z "${1}" ]; then
  usage
else
  MODE=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
fi

case "${MODE}" in
  -d|--disable|disable)
    disable_gpd_pocket_config;;
  -e|--enable|enable)
    enable_gpd_pocket_config;;
  -h|--h|-help|--help|-?|help)
    usage;;
  *)
    echo "ERROR! \"${MODE}\" is not a supported parameter."
    usage;;
esac