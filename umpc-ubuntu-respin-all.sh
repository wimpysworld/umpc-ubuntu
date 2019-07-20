#!/usr/bin/env bash

sudo true
for ISO in ubuntu-mate-18.04.2-desktop-amd64.iso ubuntu-mate-18.10-desktop-amd64.iso ubuntu-mate-19.04-beta-desktop-amd64.iso; do
  for POCKET in gpd-pocket gpd-pocket2; do
    sudo ./gpd-pocket-ubuntu-respin.sh -d ${POCKET} ${ISO}
  done
done

for POCKET_ISO in *-gpd-pocket*.iso; do
  ~/Scripts/mate/sign_image.sh ${POCKET_ISO}
done