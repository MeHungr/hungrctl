#!/bin/bash
# lib/paths.sh — Sets up and exports directory paths for hungrctl

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"

# ===== Load .env if present =====
CONFIG_PATH="$ROOT_DIR/.env"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"

# ===== Helper: Resolve path relative to ROOT_DIR =====
resolve_path() {
    case "$1" in
        /*) echo "$1" ;;                     # Already absolute
        *) echo "$ROOT_DIR/$1" ;;           # Make relative absolute
    esac
}

# ===== Resolve and create output dir before realpath =====
RAW_OUTPUT_DIR="$(resolve_path "${OUTPUT_DIR:-output}")"
mkdir -p "$RAW_OUTPUT_DIR"
OUTPUT_DIR="$(realpath "$RAW_OUTPUT_DIR")"

# ===== Define subdirectories =====
LOG_DIR="$OUTPUT_DIR/logs"
BACKUP_DIR="$OUTPUT_DIR/backups"
BASELINE_DIR="$OUTPUT_DIR/baselines"
TMP_DIR="$OUTPUT_DIR/tmp"

# ===== Ensure all required directories exist =====
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$BASELINE_DIR" "$TMP_DIR"

# ===== Export all global paths =====
export ROOT_DIR OUTPUT_DIR LOG_DIR BACKUP_DIR BASELINE_DIR TMP_DIR
