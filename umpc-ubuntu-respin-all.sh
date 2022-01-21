#!/usr/bin/env bash

sudo true
for ISO_IN in ubuntu-mate-20.04.3-desktop-amd64.iso ubuntu-mate-21.10-desktop-amd64.iso; do
  for UMPC in gpd-pocket gpd-pocket2 gpd-pocket3 gpd-micropc gpd-p2-max gpd-win2 gpd-win-max topjoy-falcon; do
    echo "Making ${ISO_IN} for ${UMPC}"
    ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${UMPC}\.iso/")
    if [ ! -e "${ISO_OUT}" ]; then
      sudo ./umpc-ubuntu-respin.sh -d ${UMPC} "${ISO_IN}"
      if [ -x "${HOME}/Scripts/mate/sign_image.sh" ]; then
        "${HOME}"/Scripts/mate/sign_image.sh "${ISO_OUT}"
      fi
    else
      echo " - ${ISO_OUT} is already built."
    fi
  done
  echo
done
