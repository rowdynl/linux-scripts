#!/bin/bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

docker pull ghcr.io/home-assistant/home-assistant:stable
docker pull ghcr.io/esphome/esphome
docker pull hotio/bazarr:latest
docker pull tautulli/tautulli:latest
docker pull linuxserver/code-server:latest
docker pull hotio/jackett:latest
docker pull linuxserver/prowlarr:latest
docker pull linuxserver/radarr:latest
docker pull influxdb:latest
docker pull mariadb:latest
docker pull phpmyadmin:latest
docker pull ghcr.io/music-assistant/server:latest
docker pull haugene/transmission-openvpn:latest
docker pull linuxserver/sabnzbd:latest
docker pull sctx/overseerr
docker pull ghcr.io/blakeblackshear/frigate:stable
docker pull eclipse-mosquitto:stable

echo ""
echo "DONE"
