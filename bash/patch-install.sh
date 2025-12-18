#!/bin/sh

# This downloads a script to enable hardware transcoding on non valid Synology
# https://github.com/likeadoc/synocodectool-patch

# USAGE: sudo ./patch.sh -h

rm patch.sh
wget https://raw.githubusercontent.com/likeadoc/synocodectool-patch/master/patch.sh
chmod +x patch.sh
