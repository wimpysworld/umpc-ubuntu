#!/usr/bin/env bash

sudo true
for ISO_IN in ubuntu-mate-19.10-desktop-amd64.iso; do
  for UMPC in gpd-pocket gpd-pocket2 gpd-micropc gpd-p2-max topjoy-falcon; do
    sudo ./umpc-ubuntu-respin.sh -d ${UMPC} ${ISO_IN}
    if [ -e ~/Scripts/mate/sign_image.sh ]; then
      ISO_OUT=$(basename "${ISO_IN}" | sed "s/\.iso/-${UMPC}\.iso/")
      ~/Scripts/mate/sign_image.sh ${ISO_OUT}
    fi
  done
done
