#!/bin/bash
# setup/paths.sh

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"

# Load config
CONFIG_PATH="$ROOT_DIR/config.env"
[ -f "$CONFIG_PATH" ] && source "$CONFIG_PATH"

# Helper to resolve path
resolve_path() {
    case "$1" in
        /*) echo "$1" ;;                     # absolute
        *) echo "$ROOT_DIR/$1" ;;           # relative to root
    esac
}

# Resolve OUTPUT_DIR first
RAW_OUTPUT_DIR="$(resolve_path "${OUTPUT_DIR:-output}")"

# Now define others based on resolved OUTPUT_DIR
RAW_LOG_DIR="$RAW_OUTPUT_DIR/logs"
RAW_BACKUP_DIR="$RAW_OUTPUT_DIR/backups"
RAW_BASELINE_DIR="$RAW_OUTPUT_DIR/baselines"

# Create all dirs before resolving them
mkdir -p "$RAW_OUTPUT_DIR" "$RAW_LOG_DIR" "$RAW_BACKUP_DIR" "$RAW_BASELINE_DIR"

# Now realpath them (safely)
export OUTPUT_DIR="$(realpath "$RAW_OUTPUT_DIR")"
export LOG_DIR="$(realpath "$RAW_LOG_DIR")"
export BACKUP_DIR="$(realpath "$RAW_BACKUP_DIR")"
export BASELINE_DIR="$(realpath "$RAW_BASELINE_DIR")"
export ROOT_DIR


