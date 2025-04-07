#!/bin/bash

# ===== Resolve script paths =====
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"

# ===== Source the config file =====
CONFIG_PATH="$ROOT_DIR/config.sh"
[ -f "$CONFIG_PATH" ] && source "$CONFIG_PATH"

# ===== Source log functions =====
source "$ROOT_DIR/lib/log.sh"

# ===== Detect distro =====
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID,,}"
else
    DISTRO="unknown"
fi


# ===== Resolve output and tmp directories =====
OUTPUT_DIR="${OUTPUT_DIR:-output}"  # Default to "output" if not set
LOG_DIR="$OUTPUT_DIR/logs"
BACKUP_DIR="$OUTPUT_DIR/backups"
BASELINE_DIR="$OUTPUT_DIR/baselines"
TMP_DIR="$OUTPUT_DIR/tmp"

# ===== Helper function to resolve relative paths to absolute =====
resolve_path() {
    case "$1" in
        /*) echo "$1" ;;  # If it's already an absolute path, return it
        *) echo "$ROOT_DIR/$1" ;;  # If it's relative, append it to ROOT_DIR
    esac
}

# ===== Create all necessary directories =====
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$BASELINE_DIR" "$TMP_DIR"

# ===== Export final resolved paths =====
export LOG_DIR="$(realpath "$LOG_DIR")"
export BACKUP_DIR="$(realpath "$BACKUP_DIR")"
export BASELINE_DIR="$(realpath "$BASELINE_DIR")"
export TMP_DIR="$(realpath "$TMP_DIR")"
export ROOT_DIR
export DISTRO