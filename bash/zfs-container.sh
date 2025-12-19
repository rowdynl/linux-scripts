#!/usr/bin/env bash
# zfs-container.sh
# Create and remove a ZFS-backed Docker volume for a container stack.
#
# Usage:
#   sudo zfs-container <name> [profile] [quota] [-v|--verbose] [-q|--quiet]
#   sudo zfs-container --delete|-d <name> [--force|-f] [-v|--verbose] [-q|--quiet]
#
# Config file:
#   /etc/zfs-container.conf (optional)
#   - Base settings (pool, parent, mount base, owner)
#   - Profile definitions: PROFILES_<name>="prop=val;prop=val;..."
#
# Installation
# chmod a+x zfs-container.sh
# sudo ln -s /scripts/bash/zfs-container.sh /usr/local/sbin/zfs-container
set -euo pipefail

# ---------- Defaults ----------
ZFS_POOL_DEFAULT="tank"
ZFS_PARENT_DEFAULT="tank/docker/bind-mounts"
MOUNT_BASE_DEFAULT="/docker/bind-mounts"
OWNER_UID_DEFAULT="1000"
OWNER_GID_DEFAULT="1000"

CONF_FILE="/etc/zfs-container.conf"

# Load config if present (may override defaults and define profiles)
if [[ -r "$CONF_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONF_FILE"
fi

# Effective settings (env or defaults)
ZFS_POOL="${ZFS_POOL:-$ZFS_POOL_DEFAULT}"
ZFS_PARENT="${ZFS_PARENT:-$ZFS_PARENT_DEFAULT}"
MOUNT_BASE="${MOUNT_BASE:-$MOUNT_BASE_DEFAULT}"
OWNER_UID="${OWNER_UID:-$OWNER_UID_DEFAULT}"
OWNER_GID="${OWNER_GID:-$OWNER_GID_DEFAULT}"

QUIET="false"
VERBOSE="false"

# ---------- Output helpers ----------
usage() {
  cat <<EOF
Usage:
  sudo $(basename "$0") <name> [profile] [quota] [-v|--verbose] [-q|--quiet]
  sudo $(basename "$0") --delete|-d <name> [--force|-f] [-v|--verbose] [-q|--quiet]

Profiles:
  Built-in: default | db | media
  Configurable: define PROFILES_<name> in ${CONF_FILE}, e.g.:
    PROFILES_logs="compression=lz4;recordsize=128K;atime=off"

Quota:
  Optional ZFS filesystem quota, e.g. 50G, 1T (uses zfs set quota=...).

Options:
  -d, --delete    Delete/remove the Docker volume and ZFS dataset for <name>
  -f, --force     With --delete/-d: stop/remove containers that reference the volume
  -v, --verbose   Verbose progress output
  -q, --quiet     Suppress non-error output

Config file keys (optional):
  ZFS_POOL, ZFS_PARENT, MOUNT_BASE, OWNER_UID, OWNER_GID
  PROFILES_<name>="prop=val;prop=val;..."
EOF
  exit 1
}

log_min()      { [[ "$QUIET" == "true" ]] && return 0; echo -e "$*"; }
log_verbose()  { [[ "$QUIET" == "true" ]] && return 0; [[ "$VERBOSE" == "true" ]] || return 0; echo -e "$*"; }
err()          { echo -e "$*" >&2; }
require_cmd()  { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 2; }; }
valid_quota()  { [[ "$1" =~ ^[0-9]+[BKMGTPZE]?$ ]]; }

# ---------- Profile application ----------
apply_profile_props() {
  # Apply a semicolon-separated list of ZFS properties to a dataset
  local ds="$1" props="$2"
  IFS=';' read -r -a entries <<< "$props"
  for kv in "${entries[@]}"; do
    [[ -z "$kv" ]] && continue
    # Trim whitespace and apply
    kv="${kv//[$'\t\r\n ']/}"
    zfs set "$kv" "$ds"
  done
}

profile_from_config() {
  # Return 0 if profile exists in config and echo its prop string
  local profile="$1"
  local varname="PROFILES_${profile}"
  if [[ -n "${!varname-}" ]]; then
    echo "${!varname}"
    return 0
  fi
  return 1
}

apply_profile() {
  local ds="$1" profile="${2:-default}"

  # If the profile is defined in the config file, use it
  if props=$(profile_from_config "$profile"); then
    log_verbose "Applying config profile '${profile}' to ${ds}: ${props}"
    apply_profile_props "$ds" "$props"
    return
  fi

  # Built-in fallbacks
  log_verbose "Applying built-in profile '${profile}' to ${ds}"
  case "$profile" in
    default)
      zfs set compression=lz4 "$ds"
      zfs set atime=off        "$ds"
      ;;
    db)
      zfs set compression=lz4        "$ds"
      zfs set recordsize=16K         "$ds"
      zfs set logbias=latency        "$ds"
      zfs set primarycache=metadata  "$ds"
      zfs set atime=off              "$ds"
      ;;
    media)
      zfs set compression=lz4 "$ds"
      zfs set recordsize=1M   "$ds"
      zfs set atime=off       "$ds"
      ;;
    *)
      err "Unknown profile '$profile'. Define PROFILES_${profile} in ${CONF_FILE} or use: default | db | media"
      exit 3
      ;;
  esac
}

# ---------- Core ops ----------
ensure_parent() {
  if ! zfs list -H -o name "$ZFS_PARENT" >/dev/null 2>&1; then
    log_verbose "Creating parent dataset: $ZFS_PARENT"
    zfs create -p -o mountpoint="$MOUNT_BASE" "$ZFS_PARENT"
  else
    local mp
    mp=$(zfs get -H -o value mountpoint "$ZFS_PARENT")
    if [[ "$mp" != "$MOUNT_BASE" ]]; then
      log_verbose "Setting mountpoint of $ZFS_PARENT to $MOUNT_BASE"
      zfs set mountpoint="$MOUNT_BASE" "$ZFS_PARENT"
    fi
  fi
  mkdir -p "$MOUNT_BASE"
}

docker_volume_exists()      { docker volume inspect "$1" >/dev/null 2>&1; }
containers_using_volume()   { docker ps -a --filter "volume=$1" -q; }

create_path() {
  local name="$1" profile="${2:-default}" quota="${3:-}"
  require_cmd zfs
  require_cmd docker

  ensure_parent

  local ds="${ZFS_PARENT}/${name}"
  local mp="${MOUNT_BASE}/${name}"

  if zfs list -H -o name "$ds" >/dev/null 2>&1; then
    log_verbose "Dataset already exists: $ds"
  else
    log_verbose "Creating dataset: $ds"
    zfs create -o mountpoint="$mp" "$ds"
  fi

  apply_profile "$ds" "$profile"

  if [[ -n "${quota}" ]]; then
    if ! valid_quota "$quota"; then
      err "Invalid quota '${quota}'. Examples: 50G, 1024M, 1T"
      exit 4
    fi
    log_verbose "Setting quota=${quota} on ${ds}"
    zfs set "quota=${quota}" "$ds"
  fi

  chown -R "${OWNER_UID}:${OWNER_GID}" "$mp"

  if docker_volume_exists "$name"; then
    log_verbose "Docker volume exists: $name (reusing)"
  else
    log_verbose "Creating Docker volume: $name -> bind ${mp}"
    docker volume create \
      --driver local \
      --opt type=none \
      --opt o=bind \
      --opt "device=${mp}" \
      "$name"
  fi

  log_min "✅ ${name}: dataset=${ds} mount=${mp} volume=${name}"
}

delete_path() {
  local name="$1" force="${2:-false}"
  require_cmd zfs
  require_cmd docker

  local ds="${ZFS_PARENT}/${name}"
  local mp="${MOUNT_BASE}/${name}"

  local refs
  refs=$(containers_using_volume "$name" || true)

  if [[ -n "$refs" && "$force" != "true" ]]; then
    err "Refusing to delete. Containers referencing volume '${name}':\n$refs\nUse: sudo $(basename "$0") -d ${name} -f"
    exit 5
  fi

  if [[ -n "$refs" && "$force" == "true" ]]; then
    log_verbose "Stopping/removing containers referencing volume '${name}' ..."
    # shellcheck disable=SC2086
    docker stop $refs >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    docker rm   $refs >/dev/null 2>&1 || true
  fi

  if docker_volume_exists "$name"; then
    log_verbose "Removing Docker volume: ${name}"
    docker volume rm "$name" >/dev/null || {
      err "Docker volume '${name}' still in use. Try '-f' or remove containers manually."
      exit 6
    }
  else
    log_verbose "Docker volume '${name}' not found; continuing..."
  fi

  if zfs list -H -o name "$ds" >/dev/null 2>&1; then
    log_verbose "Destroying dataset: ${ds}"
    zfs destroy -r "$ds"
  else
    log_verbose "Dataset '${ds}' not found; nothing to destroy."
  fi

  rmdir "$mp" 2>/dev/null || true
  log_min "✅ Removed '${name}' (volume & dataset)"
}

# ---------- CLI parsing ----------
[[ $# -lt 1 ]] && usage

DELETE_MODE="false"
FORCE_DELETE="false"
POSITIONALS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete|-d)  DELETE_MODE="true"; shift ;;
    --force|-f)   FORCE_DELETE="true"; shift ;;
    --verbose|-v) VERBOSE="true"; shift ;;
    --quiet|-q)   QUIET="true"; shift ;;
    --) shift; break ;;
    -*)
      usage ;;
    *)
      POSITIONALS+=("$1"); shift ;;
  esac
done
while [[ $# -gt 0 ]]; do POSITIONALS+=("$1"); shift; done

if [[ "$DELETE_MODE" == "true" ]]; then
  [[ ${#POSITIONALS[@]} -ge 1 ]] || usage
  name="${POSITIONALS[0]}"
  delete_path "$name" "$FORCE_DELETE"
else
  [[ ${#POSITIONALS[@]} -ge 1 ]] || usage
  name="${POSITIONALS[0]}"
  profile="${POSITIONALS[1]:-default}"
  quota="${POSITIONALS[2]:-}"
  create_path "$name" "$profile" "$quota"
fi
