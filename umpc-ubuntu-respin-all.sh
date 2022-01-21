#!/usr/bin/env bash

# Make sure we are a regular user
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! You must be a regular user to run $(basename "${0}")"
  exit 1
fi

sudo true
for ISO_IN in ubuntu-mate-20.04.3-desktop-amd64.iso ubuntu-mate-21.10-desktop-amd64.iso; do
  for UMPC in gpd-pocket gpd-pocket2 gpd-pocket3 gpd-micropc gpd-p2-max gpd-win2 gpd-win-max topjoy-falcon; do
    echo "Making ${ISO_IN} for ${UMPC}"
    ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${UMPC}\.iso/")
    if [ ! -e "${ISO_OUT}" ]; then
      sudo ./umpc-ubuntu-respin.sh -d ${UMPC} "${ISO_IN}"
    else
      echo " - ${ISO_OUT} is already built."
    fi
    if [ -x "${HOME}/Scripts/mate/sign_image.sh" ]; then
      if [ ! -e "${ISO_OUT}.sha256" ]; then
        "${HOME}"/Scripts/mate/sign_image.sh "${ISO_OUT}"
      else
        echo " - ${ISO_OUT} is already signed."
      fi
    else
      echo " - Image signer not found."
    fi
    echo
  done
done
