# GPD Pocket and GPD Pocket 2 hardware configuration for Ubuntu

A couple of scripts for [GPD Pocket](https://gpd.hk/gpdpocket) and [GPD Pocket 
2](https://gpd.hk/gpdpocket2) Ubuntu users.

  * `gpd-pocket-ubuntu.sh`: installs the required hardware configuration on a running Ubuntu install.
  * `gpd-pocket-ubuntu-respin.sh`: respin and existing Ubuntu .iso image add inject the required hardware configuration.

![GPD Pockets](gpd-pockets.jpg "The GPD Pocket & GPD Pocket 2 running Ubuntu MATE 18.10")

**NOTE!** Both scripts have only been tested on [Ubuntu 
MATE](https://ubuntu-mate.org) only tested on Ubuntu MATE 18.10. It is 
unlikely they will work completely on Ubuntu is your use Wayland. Almost 
certainly only works reliably on one of the Ubuntu 18.10 flavoursm, or newer.

## Pre-configured image

The Ubuntu MATE team offers a bespoke image for the GPD Pocket and GPD Pocket 
2 that includes the hardware specific tweaks to get these devices working 
*"out of the box"* without any faffing about.

  * https://ubuntu-mate.org/download/

### gpd-pocket-ubuntu.sh

Install one of the Ubuntu 18.10 (or newer) flavours on a GPD Pocket or GPD
Pocket 2 and run the following to inject the required hardware configuration.

    git clone https://github.com/wimpysworld/gpd-pocket2-ubuntu.git
    cd gpd-pocket2-ubuntu
    sudo ./gpd-pocket2-ubuntu.sh enable || disable

You must supply one of the following modes of operation

  * `enable`  : apply the GPD Pocket hardware configuration
  * `disable` : remove the GPD Pocket hardware configuration
  * `help`    : This help.

### gpd-pocket-ubuntu-respin.sh

    git clone https://github.com/wimpysworld/gpd-pocket2-ubuntu.git
    cd gpd-pocket2-ubuntu

  * Download an .iso image for one of the Ubuntu 18.10 (or newer) flavours.
  * Edit `gpd-pocket-ubuntu-respin.sh` and update the `ISO_IN=` with the full path the .iso your downloaded.

    sudo ./gpd-pocket-ubuntu-respin.sh

A new .iso will be created that includes the additional hardware tweaks
required by the GPD Pocket and GPD Pocket 2.
