#!/usr/bin/env bash

# Set to either "gpd-pocket", "gpd-pocket2", "gpd-pocket3", "gpd-p2-max", "gpd-micropc", "gpd-win2", "gpd-win-max" or "topjoy-falcon"
UMPC="gpd-pocket3"
XORG_CONF_PATH="/usr/share/X11/xorg.conf.d"
INTEL_CONF="${XORG_CONF_PATH}/20-${UMPC}-intel.conf"
MODPROBE_CONF="/etc/modprobe.d/alsa-${UMPC}.conf"
MONITOR_CONF="${XORG_CONF_PATH}/40-${UMPC}-monitor.conf"
MONITORS_XML="/var/lib/gdm3/.config/${UMPC}-monitors.xml"
TRACKPOINT_CONF="${XORG_CONF_PATH}/80-${UMPC}-trackpoint.conf"
TOUCH_RULES="/etc/udev/rules.d/99-${UMPC}-touch.rules"
BRCM4356_CONF="/lib/firmware/brcm/brcmfmac4356-pcie.txt"
GRUB_DEFAULT_CONF="/etc/default/grub"
GRUB_D_CONF="/etc/default/grub.d/${UMPC}.cfg"
CONSOLE_CONF="/etc/default/console-setup"
GSCHEMA_OVERRIDE="/usr/share/glib-2.0/schemas/90-${UMPC}.gschema.override"
EDID="/lib/firmware/edid/${UMPC}-edid.bin"
HWDB_CONF="/etc/udev/hwdb.d/61-${UMPC}-sensor-local.hwdb"

# Copy file from /data to it's intended location
function inject_data() {
  local SOURCE_FILE=""
  local TARGET_FILE="${1}"
  local TARGET_DIR=$(dirname "${TARGET_FILE}")
  if [ -n "${2}" ] && [ -f "${2}" ]; then
    SOURCE_FILE="${2}"
  else
    SOURCE_FILE="data/$(basename "${TARGET_FILE}")"
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

function enable_umpc_config() {
  # NOTE! Do not inject this configuration anymore. The defaults are sane.
  # Enable Intel SNA, DRI1/3 and TearFree.
  # inject_data "${INTEL_CONF}"

  # Rotate the monitor.
  inject_data "${MONITOR_CONF}"
  inject_data "${MONITORS_XML}"

  # Scroll while holding down the right track point button
  inject_data "${TRACKPOINT_CONF}"

  # Rotate the touchscreen.
  inject_data "${TOUCH_RULES}"
  # Reload udev rules
  udevadm control --reload-rules
  udevadm trigger

  # Configure kernel modules
  inject_data "${MODPROBE_CONF}"

  # Apply device specific gschema overrides
  inject_data "${GSCHEMA_OVERRIDE}"

  # Add device specific /etc/grub.d configuration
  inject_data "${GRUB_D_CONF}"

  # Device specific tweaks
  case ${UMPC} in
    gpd-pocket)
      # Add BRCM4356 firmware configuration
      inject_data "${BRCM4356_CONF}"
      # Reload the brcmfmac kernel module
      modprobe -r brcmfmac
      modprobe brcmfmac

      # Increase console font size
      sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

      # Display Scaler
      inject_data "/usr/bin/umpc-display-scaler"
      inject_data "/etc/xdg/autostart/umpc-display-scaler.desktop"
      inject_data "/usr/share/applications/umpc-display-scaler.desktop"
      ;;
    gpd-pocket2)
      # Increase console font size
      sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

      # Display Scaler
      inject_data "/usr/bin/umpc-display-scaler"
      inject_data "/etc/xdg/autostart/umpc-display-scaler.desktop"
      inject_data "/usr/share/applications/umpc-display-scaler.desktop"
      ;;
    gpd-pocket3)
      # Increase console font size
      sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

      # Add automatic screen rotation
      gcc -O2 "data/umpc-display-rotate.c" -o "/usr/bin/umpc-display-rotate" -lm
      inject_data "/etc/xdg/autostart/umpc-display-rotate.desktop"
      inject_data "${HWDB_CONF}"
      systemd-hwdb update
      udevadm trigger -v -p DEVNAME=/dev/iio:device0
      systemctl restart iio-sensor-proxy.service

      # Display Scaler
      inject_data "/usr/bin/umpc-display-scaler"
      inject_data "/etc/xdg/autostart/umpc-display-scaler.desktop"
      inject_data "/usr/share/applications/umpc-display-scaler.desktop"
      ;;
    gpd-p2-max)
      # Increase console font size
      sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"
      ;;
    gpd-micropc)
      true;;
    gpd-win2)
      true;;
    gpd-win-max)
      # Add device specific EDID
      inject_data "${EDID}"
      ;;
    topjoy-falcon)
      # Increase console font size
      sed -i 's/FONTSIZE="8x16"/FONTSIZE="16x32"/' "${CONSOLE_CONF}"

      # Add automatic screen rotation
      gcc -O2 "data/umpc-display-rotate.c" -o "/usr/bin/umpc-display-rotate" -lm
      inject_data "/etc/xdg/autostart/umpc-display-rotate.desktop"
      inject_data "${HWDB_CONF}"
      systemd-hwdb update
      udevadm trigger -v -p DEVNAME=/dev/iio:device0
      systemctl restart iio-sensor-proxy.service

      # Display Scaler
      inject_data "/usr/bin/umpc-display-scaler"
      inject_data "/etc/xdg/autostart/umpc-display-scaler.desktop"
      inject_data "/usr/share/applications/umpc-display-scaler.desktop"
      ;;
  esac

  update-grub

  echo "UMPC hardware configuration is applied. Please reboot to complete the setup."
}

function disable_umpc_config() {
  # Remove the UMPC Pocket hardware configuration
  for CONFIG in ${MONITOR_CONF} ${MONITORS_XML} ${TOUCH_CONF} ${TRACKPOINT_CONF} ${GSCHEMA_OVERRIDE} ${EDID} ${BRCM4356_CONF}; do
    if [ -f "${CONFIG}" ]; then
      rm -fv "${CONFIG}"
    fi
  done

  # Remove the framebuffer rotation
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="fbcon=rotate:1 quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet/' "${GRUB_DEFAULT_CONF}"
  sed -i 's/GRUB_CMDLINE_LINUX="fbcon=rotate:1"/GRUB_CMDLINE_LINUX=""/' "${GRUB_DEFAULT_CONF}"
  sed -i '/GRUB_GFXMODE=1200x1920x32/d' "${GRUB_DEFAULT_CONF}"
  update-grub

  # Restore tty font size
  sed -i 's/FONTSIZE=16x32"/FONTSIZE="8x16"/' "${CONSOLE_CONF}"
  # Remove apps
  rm -fv /usr/bin/umpc-display-rotate
  rm -fv /etc/xdg/autostart/umpc-display-rotate.desktop
  rm -fv /usr/bin/umpc-display-scaler
  rm -fv /etc/xdg/autostart/umpc-display-scaler.desktop
  rm -fv /usr/share/applications/umpc-display-scaler.desktop

  echo "UMPC hardware configuration is removed. Please reboot to complete the setup."
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
if [ "$(id -u)" -ne 0 ]; then
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

if [ -z "${UMPC}" ]; then
    echo "ERROR! You must supply the name of the device you want to apply modifications for."
    usage
fi

case "${UMPC}" in
  gpd-pocket|gpd-pocket2|gpd-pocket3|gpd-micropc|gpd-p2-max|gpd-win2|gpd-win-max|topjoy-falcon) true;;
  *) echo "ERROR! Unknown device name given."
     usage;;
esac

case "${MODE}" in
  -d|--disable|disable)
    disable_umpc_config;;
  -e|--enable|enable)
    enable_umpc_config;;
  -h|--h|-help|--help|-?|help)
    usage;;
  *)
    echo "ERROR! \"${MODE}\" is not a supported parameter."
    usage;;
esac
