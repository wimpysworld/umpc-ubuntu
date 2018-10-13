#!/usr/bin/env bash

# Define variables for the xorg configs
XORG_CONF_PATH="/usr/share/X11/xorg.conf.d"
MONITOR_CONF="${XORG_CONF_PATH}/40-gpd-pocket2-monitor.conf"
TOUCH_CONF="${XORG_CONF_PATH}/99-gpd-pocket2-touchscreen.conf"

function enable_gpd_pocket2_config() {
  # Use heredocs to write GPD Pocket2 monitor and touchscreen rotation configs
  mkdir -p "${XORG_CONF_PATH}"

  # Rotate the monitor.
  cat << MONITOR > "${MONITOR_CONF}"
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

  # Rotate the framebuffer
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="fbcon=rotate:1 quiet/' /etc/default/grub
  update-grub

  echo "GPD Pocket2 monitor and touchscreen rotation configuration is applied. Please reboot to complete the setup."
}

function disable_gpd_pocket2_config() {
  # Remove the GPD Pocket 2 monitor and touchscreen rotation configurations
  for CONFIG in ${MONITOR_CONF} ${TOUCH_CONF}; do
    if [ -f ${CONFIG} ]; then
      rm -f "${CONFIG}"
    fi
  done

  # Remove the framebuffer rotation
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="fbcon=rotate:1/GRUB_CMDLINE_LINUX_DEFAULT="/' /etc/default/grub
  update-grub

  echo "GPD Pocket2 monitor and touchscreen rotation configuration is removed. Please reboot to complete the setup."
}

function usage() {
    echo
    echo "Usage"
    echo "  ${0} enable || disable"
    echo ""
    echo "You must supply one of the following modes of operation"
    echo "  enable  : apply the GPD Pocket2 monitor and touchscreen rotation configuration"
    echo "  disable : remove the GPD Pocket2 monitor and touchscreen rotation configuration"
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
    disable_gpd_pocket2_config;;
  -e|--enable|enable)
    enable_gpd_pocket2_config;;
  -h|--h|-help|--help|-?|help)
    usage;;
  *)
    echo "ERROR! \"${MODE}\" is not a supported parameter."
    usage;;
esac
