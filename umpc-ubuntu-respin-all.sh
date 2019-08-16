#!/usr/bin/env bash

sudo true
for ISO_IN in ubuntu-mate-18.04.3-desktop-amd64.iso; do
  for UMPC in gpd-pocket gpd-pocket2 gpd-micropc topjoy-falcon; do
    sudo ./umpc-ubuntu-respin.sh -d ${UMPC} ${ISO_IN}
    if [ -e ~/Scripts/mate/sign_image.sh ]; then
      ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${UMPC}\.iso/")
      ~/Scripts/mate/sign_image.sh ${ISO_OUT}
    fi
  done
done
