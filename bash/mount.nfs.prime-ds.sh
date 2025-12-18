#!/bin/bash
#
# Mounts the NFS shares to the old NAS after a reboot

sudo mount -t nfs 192.168.178.100:/volume1/docker /mnt/prime-ds/docker/
sudo mount -t nfs 192.168.178.100:/volume1/public /mnt/prime-ds/public/
sudo mount -t nfs 192.168.178.100:/volume1/media /mnt/prime-ds/media/
sudo mount -t nfs 192.168.178.100:/volume1/movies /mnt/prime-ds/movies/
sudo mount -t nfs 192.168.178.100:/volume1/music /mnt/prime-ds/music/
sudo mount -t nfs 192.168.178.100:/volume1/scripts /mnt/prime-ds/scripts/
sudo mount -t nfs 192.168.178.100:/volume1/series /mnt/prime-ds/series/
sudo mount -t nfs 192.168.178.100:/volume1/video /mnt/prime-ds/video/
