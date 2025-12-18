#!/usr/bin/env bash
#
# zfs-container-helper.sh
#
# Create a ZFS dataset + Docker named volume (bind) under /docker/bind_mounts/<name>
#
# Usage:
#   sudo ./container_helper.sh <name> <profile> [quota]
#
# Profiles:
#   general — recordsize=128K, compression=lz4, xattr=sa, atime=off
#   db      — recordsize=16K,  compression=lz4, xattr=sa, atime=off
#   media   — recordsize=1M,   compression=lz4, xattr=sa, atime=off
#   logs    — recordsize=64K,  compression=lz4, xattr=sa, atime=off
#
# Aliases (map to 'db'):
#   postgres, mariadb, mysql, mongo, influx
#
# Examples:
#   sudo ./container_helper.sh postgres db 50G
#   sudo ./container_helper.sh mariadb  db 50G
#   sudo ./container_helper.sh mongo    db 50G
#   sudo ./container_helper.sh influx   db 50G
#   sudo ./container_helper.sh plex     media 200G
#
# Installation
# chmod a+x zfs-container-helper.sh
# sudo ln -s /scripts/bash/zfs-container-helper.sh /usr/local/sbin/zfs-container
#
#
# Notes:
# - This script manages ZFS datasets and Docker named volumes that bind to them.
# - It assumes a ZFS pool 'tank' and uses /docker as the Docker data-root mountpoint tree.

set -Eeuo pipefail

POOL="tank"
ROOT_DS="${POOL}/docker"
ROOT_MNT="/docker"
BIND_PARENT_DS="${ROOT_DS}/bind_mounts"
BIND_PARENT_MNT="${ROOT_MNT}/bind_mounts"

DEFAULT_QUOTA=""   # e.g. "50G" (empty = no quota)

log() { printf '\e[1;32m>>> %s\e[0m\n' "$*"; }
err() { printf '\e[1;31mERROR: %s\e[0m\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage:
  sudo ./container_helper.sh <name> <profile> [quota]

Profiles:
  general   — recordsize=128K, compression=lz4, xattr=sa, atime=off
  db        — recordsize=16K,  compression=lz4, xattr=sa, atime=off
  media     — recordsize=1M,   compression=lz4, xattr=sa, atime=off
  logs      — recordsize=64K,  compression=lz4, xattr=sa, atime=off

Aliases (map to 'db'):
  postgres, mariadb, mysql, mongo, influx

Examples:
  sudo ./container_helper.sh postgres db 50G
  sudo ./container_helper.sh mariadb  db 50G
  sudo ./container_helper.sh mongo    db 50G
  sudo ./container_helper.sh influx   db 50G
  sudo ./container_helper.sh plex     media 200G
USAGE
}

# Help flags or missing args
if [[ $# -lt 2 ]] || [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
  usage; exit 1
fi

if [[ $EUID -ne 0 ]]; then err "Run as root (sudo)."; exit 1; fi
command -v zfs    >/dev/null || { err "Missing 'zfs'. Install: sudo apt install -y zfsutils-linux"; exit 1; }
command -v docker >/dev/null || { err "Missing 'docker'. Install Docker before using this script."; exit 1; }

NAME="$1"
PROFILE="$2"
QUOTA="${3:-$DEFAULT_QUOTA}"

# Map aliases to 'db'
case "$PROFILE" in
  postgres|mariadb|mysql|mongo|influx) PROFILE="db" ;;
esac

# Translate profile to properties
# Note: 'recordsize' is for filesystem datasets (bind mounts). For zvols, use 'volblocksize'.
case "$PROFILE" in
  general)
    RECORDSIZE="128K"; COMPRESSION="lz4"; XATTR="sa"; ATIME="off"
    ;;
  db)
    RECORDSIZE="16K";  COMPRESSION="lz4"; XATTR="sa"; ATIME="off"
    ;;
  media)
    RECORDSIZE="1M";   COMPRESSION="lz4"; XATTR="sa"; ATIME="off"
    ;;
  logs)
    RECORDSIZE="64K";  COMPRESSION="lz4"; XATTR="sa"; ATIME="off"
    ;;
  *)
    err "Unknown profile: '${PROFILE}'. Use: general|db|media|logs (or aliases: postgres|mariadb|mysql|mongo|influx)."
    usage; exit 1
    ;;
esac

log "Profile '${PROFILE}' → recordsize=${RECORDSIZE}, compression=${COMPRESSION}, xattr=${XATTR}, atime=${ATIME}"
[[ -n "$QUOTA" ]] && log "Quota: ${QUOTA}"

# 1) Ensure root dataset and mountpoint /docker exist
if ! zfs list -H -o name "$ROOT_DS" >/dev/null 2>&1; then
  log "Creating root dataset ${ROOT_DS}…"
  zfs create "$ROOT_DS"
  zfs set mountpoint="$ROOT_MNT" "$ROOT_DS"
fi
# Baseline properties on root (idempotent)
zfs set compression="lz4" "$ROOT_DS" || true
zfs set atime="off"       "$ROOT_DS" || true
zfs set xattr="sa"        "$ROOT_DS" || true
zfs set recordsize="128K" "$ROOT_DS" || true

# 2) Ensure parent dataset /docker/bind_mounts exists
if ! zfs list -H -o name "$BIND_PARENT_DS" >/dev/null 2>&1; then
  log "Creating parent dataset ${BIND_PARENT_DS}…"
  zfs create "$BIND_PARENT_DS"
  zfs set mountpoint="$BIND_PARENT_MNT" "$BIND_PARENT_DS"
fi
# Baseline properties on parent (can differ from root if desired)
zfs set compression="lz4" "$BIND_PARENT_DS" || true
zfs set atime="off"       "$BIND_PARENT_DS" || true
zfs set xattr="sa"        "$BIND_PARENT_DS" || true
zfs set recordsize="128K" "$BIND_PARENT_DS" || true

# 3) Child dataset for this container
CHILD_DS="${BIND_PARENT_DS}/${NAME}"
CHILD_MNT="${BIND_PARENT_MNT}/${NAME}"

if zfs list -H -o name "$CHILD_DS" >/dev/null 2>&1; then
  log "Dataset ${CHILD_DS} already exists — skipping create."
else
  log "Creating dataset ${CHILD_DS}…"
  zfs create "$CHILD_DS"
  zfs set mountpoint="$CHILD_MNT" "$CHILD_DS"
fi

# Set specific properties for this container (override parent)
zfs set compression="$COMPRESSION" "$CHILD_DS" || true
zfs set atime="$ATIME"             "$CHILD_DS" || true
zfs set xattr="$XATTR"             "$CHILD_DS" || true
zfs set recordsize="$RECORDSIZE"   "$CHILD_DS" || true

# 4) Optional quota
if [[ -n "$QUOTA" ]]; then
  log "Setting quota=${QUOTA} on ${CHILD_DS}…"
  zfs set quota="$QUOTA" "$CHILD_DS"
fi

# 5) Docker named volume that binds to CHILD_MNT
VOL_NAME="${NAME}-config"
if docker volume inspect "$VOL_NAME" >/dev/null 2>&1; then
  log "Docker volume ${VOL_NAME} already exists — skipping create."
else
  log "Creating Docker named volume (bind) ${VOL_NAME} → ${CHILD_MNT}…"
  docker volume create \
    --driver local \
    --opt type=none \
    --opt o=bind \
    --opt device="$CHILD_MNT" \
    "$VOL_NAME" >/dev/null
fi

# 6) Optional: set ownership to your user (adjust 'rowdy' if needed)
# chown -R rowdy:rowdy "$CHILD_MNT" || true

# 7) Status
log "Datasets:"
zfs list "$ROOT_DS" "$BIND_PARENT_DS" "$CHILD_DS" || true
log "Properties for ${CHILD_DS}:"
zfs get -H -o property,value compression,atime,xattr,recordsize,quota "$CHILD_DS" || true
log "Docker volume inspect:"
docker volume inspect "$VOL_NAME" || true

log "Done. Example usage:"
echo "  docker run -d --name ${NAME} -v ${VOL_NAME}:/config <image>"

