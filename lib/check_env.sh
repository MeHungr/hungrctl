#!/bin/bash
# check_env.sh — Shared environment for all check scripts
# This sources all environments if they do not overlap,
# and compiles them into one sourceable script.

lib_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Load paths and config
if [[ -z "$ROOT_DIR" || -z "$BASELINE_DIR" ]]; then
	source "$lib_dir/paths.sh"
fi

# Load logging functions
if ! command -v log_info &>/dev/null; then
    source "$lib_dir/log.sh"
fi
