#!/bin/bash

# Copyright 2018 root@geeks-r-us.de

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# For further information see: http://geeks-r-us.de/2017/08/26/android-apps-auf-dem-linux-desktop/

# die when an error occurs
set -e

OPENGAPPS_RELEASEDATE="20181011"
OPENGAPPS_FILE="open_gapps-x86_64-7.1-mini-$OPENGAPPS_RELEASEDATE.zip"
OPENGAPPS_URL="https://github.com/opengapps/x86_64/releases/download/$OPENGAPPS_RELEASEDATE/$OPENGAPPS_FILE"

HOUDINI_URL="http://dl.android-x86.org/houdini/7_y/houdini.sfs"
HOUDINI_SO="https://github.com/Rprop/libhoudini/raw/master/4.0.8.45720/system/lib/libhoudini.so"

WORKDIR="$(pwd)/anbox-work"

# check if script was started with BASH
if [ ! "$(ps -p $$ -oargs= | awk '{print $1}' | grep -E 'bash$')" ]; then
   echo "Please use BASH to start the script!"
	 exit 1
fi

# check if user is root
if [ "$(whoami)" != "root" ]; then
	echo "Sorry, you are not root. Please run with sudo $0"
	exit 1
fi

# check if lzip is installed
if [ ! "$(which lzip)" ]; then
	echo -e "lzip is not installed. Please install lzip.\nExample: sudo apt install lzip"
	exit 1
fi

# check if squashfs-tools are installed
if [ ! "$(which mksquashfs)" ] || [ ! "$(which unsquashfs)" ]; then
	echo -e "squashfs-tools is not installed. Please install squashfs-tools.\nExample: sudo apt install squashfs-tools"
	exit 1
else
	MKSQUASHFS=$(which mksquashfs)
	UNSQUASHFS=$(which unsquashfs)
fi

# check if wget is installed
if [ ! "$(which wget)" ]; then
	echo -e "wget is not installed. Please install wget.\nExample: sudo apt install wget"
	exit 1
else
	WGET=$(which wget)
fi

# check if unzip is installed
if [ ! "$(which unzip)" ]; then
	echo -e "unzip is not installed. Please install unzip.\nExample: sudo apt install unzip"
	exit 1
else
	UNZIP=$(which unzip)
fi

# check if tar is installed
if [ ! "$(which tar)" ]; then
	echo -e "tar is not installed. Please install tar.\nExample: sudo apt install tar"
	exit 1
else
	TAR=$(which tar)
fi

# use sudo if installed
if [ ! "$(which sudo)" ]; then
	SUDO=""
else
	SUDO=$(which sudo)
fi

echo $WORKDIR
if [ ! -d "$WORKDIR" ]; then
    mkdir "$WORKDIR"
fi

cd "$WORKDIR"

if [ -d "$WORKDIR/squashfs-root" ]; then
  $SUDO rm -rf squashfs-root
fi

# get image from anbox
cp /snap/anbox/current/android.img .
$SUDO $UNSQUASHFS android.img

# get opengapps and install it
cd "$WORKDIR"
if [ ! -f ./$OPENGAPPS_FILE ]; then
  $WGET -q --show-progress $OPENGAPPS_URL
  $UNZIP -d opengapps ./$OPENGAPPS_FILE
fi


cd ./opengapps/Core/
for filename in *.tar.lz
do
    $TAR --lzip -xvf ./$filename
done

cd "$WORKDIR"

$SUDO rm -rf /var/snap/anbox/common/rootfs-overlay/*

$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/priv-app/

$SUDO cp -r ./$(find opengapps -type d -name "PrebuiltGmsCore")			/var/snap/anbox/common/rootfs-overlay/system/priv-app/
$SUDO cp -r ./$(find opengapps -type d -name "GoogleLoginService")		/var/snap/anbox/common/rootfs-overlay/system/priv-app/
$SUDO cp -r ./$(find opengapps -type d -name "Phonesky")			/var/snap/anbox/common/rootfs-overlay/system/priv-app/
$SUDO cp -r ./$(find opengapps -type d -name "GoogleServicesFramework")		/var/snap/anbox/common/rootfs-overlay/system/priv-app/

# load houdini and spread it
cd "$WORKDIR"
if [ ! -f ./houdini.sfs ]; then
  $WGET -q --show-progress $HOUDINI_URL
  mkdir -p houdini
  $SUDO $UNSQUASHFS -f -d ./houdini ./houdini.sfs
fi

$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/bin/

$SUDO cp -r ./houdini/houdini /var/snap/anbox/common/rootfs-overlay/system/bin/

$SUDO cp -r ./houdini/xstdata /var/snap/anbox/common/rootfs-overlay/system/bin/

$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/lib/

$SUDO $WGET -q --show-progress -P /var/snap/anbox/common/rootfs-overlay/system/lib/ $HOUDINI_SO

$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/lib/arm
$SUDO cp -r ./houdini/linker /var/snap/anbox/common/rootfs-overlay/system/lib/arm/
$SUDO cp -r ./houdini/*.so /var/snap/anbox/common/rootfs-overlay/system/lib/arm/
$SUDO cp -r ./houdini/nb /var/snap/anbox/common/rootfs-overlay/system/lib/arm/

# add houdini parser
$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/etc/binfmt_misc
echo ":arm_dyn:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\x28::/system/bin/houdini:" | tee -a /var/snap/anbox/common/rootfs-overlay/system/etc/binfmt_misc/arm_dyn > /dev/null
echo ":arm_exe:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28::/system/bin/houdini:" | tee -a /var/snap/anbox/common/rootfs-overlay/system/etc/binfmt_misc/arm_exe > /dev/null

# add features
C=$(cat <<-END
  <feature name="android.hardware.touchscreen" />\n
  <feature name="android.hardware.audio.output" />\n
  <feature name="android.hardware.camera" />\n
  <feature name="android.hardware.camera.any" />\n
  <feature name="android.hardware.location" />\n
  <feature name="android.hardware.location.gps" />\n
  <feature name="android.hardware.location.network" />\n
  <feature name="android.hardware.microphone" />\n
  <feature name="android.hardware.screen.portrait" />\n
  <feature name="android.hardware.screen.landscape" />\n
  <feature name="android.hardware.wifi" />\n
  <feature name="android.hardware.bluetooth" />"
END
)


C=$(echo $C | sed 's/\//\\\//g')
C=$(echo $C | sed 's/\"/\\\"/g')
$SUDO sed -i "/<\/permissions>/ s/.*/${C}\n&/" ./squashfs-root/system/etc/permissions/anbox.xml

$SUDO mkdir -p /var/snap/anbox/common/rootfs-overlay/system/etc/permissions/

# make wifi and bt available
$SUDO sed -i "/<unavailable-feature name=\"android.hardware.wifi\" \/>/d" ./squashfs-root/system/etc/permissions/anbox.xml
$SUDO sed -i "/<unavailable-feature name=\"android.hardware.bluetooth\" \/>/d" ./squashfs-root/system/etc/permissions/anbox.xml

$SUDO cp ./squashfs-root/system/etc/permissions/anbox.xml /var/snap/anbox/common/rootfs-overlay/system/etc/permissions/

# set processors
ARM_TYPE=",armeabi-v7a,armeabi"
$SUDO sed -i "/^ro.product.cpu.abilist=x86_64,x86/ s/$/${ARM_TYPE}/" ./squashfs-root/system/build.prop
$SUDO sed -i "/^ro.product.cpu.abilist32=x86/ s/$/${ARM_TYPE}/" ./squashfs-root/system/build.prop

$SUDO echo "persist.sys.nativebridge=1" >> ./squashfs-root/system/build.prop

# enable opengles
$SUDO echo "ro.opengles.version=131072" >> ./squashfs-root/system/build.prop

$SUDO cp ./squashfs-root/system/build.prop /var/snap/anbox/common/rootfs-overlay/system/

$SUDO chown -R 100000:100000 /var/snap/anbox/common/rootfs-overlay

until $SUDO systemctl stop snap.anbox.container-manager.service
do
	sleep 10
done

$SUDO systemctl start snap.anbox.container-manager.service
