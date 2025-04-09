#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

HOST="$(hostname)"
MODE="${1:-check}"
SUMMARY_LOG="$SUMMARY_DIR/check_credentials.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"
passwd_changed=false
shadow_changed=false
group_changed=false

check_passwd() {
    log_info "Checking passwd file integrity..."
    

    if [ ! -f "$CREDENTIALS_BASELINE_DIR/passwd.baseline" ]; then
        log_warn "No baseline file found at $CREDENTIALS_BASELINE_DIR/passwd.baseline. Creating one now..."
        cp /etc/passwd "$CREDENTIALS_BASELINE_DIR/passwd.baseline"
        chattr +i "$CREDENTIALS_BASELINE_DIR/passwd.baseline"
        log_ok "Created a baseline file for passwd."
    fi

    # Check if passwd file has been modified
    if ! diff -q "$CREDENTIALS_BASELINE_DIR/passwd.baseline" /etc/passwd > /dev/null 2>&1; then
        passwd_changed=true
        log_warn "passwd file has been modified."
        echo "------------Passwd File------------" >> "$SUMMARY_LOG"
        echo "[$HOST] passwd file has been modified at $(timestamp)" >> "$SUMMARY_LOG"
    else
        log_ok "passwd file matches baseline."
    fi
}

check_shadow() {
    log_info "Checking shadow file integrity..."
    

    if [ ! -f "$CREDENTIALS_BASELINE_DIR/shadow.baseline" ]; then
        log_warn "No baseline file found at $CREDENTIALS_BASELINE_DIR/shadow.baseline. Creating one now..."
        cp /etc/shadow "$CREDENTIALS_BASELINE_DIR/shadow.baseline"
        chattr +i "$CREDENTIALS_BASELINE_DIR/shadow.baseline"s
        log_ok "Created a baseline file for shadow."
    fi

    # Check if shadow file has been modified
    if ! diff -q "$CREDENTIALS_BASELINE_DIR/shadow.baseline" /etc/shadow > /dev/null 2>&1; then
        shadow_changed=true
        log_warn "shadow file has been modified."
        echo "------------Shadow File------------" >> "$SUMMARY_LOG"
        echo "[$HOST] shadow file has been modified at $(timestamp)" >> "$SUMMARY_LOG"
    else
        log_ok "shadow file matches baseline."
    fi
}

check_group() {
    log_info "Checking group file integrity..." 
    
    if [ ! -f "$CREDENTIALS_BASELINE_DIR/group.baseline" ]; then
        log_warn "No baseline file found at $CREDENTIALS_BASELINE_DIR/group.baseline. Creating one now..."
        cp /etc/group "$CREDENTIALS_BASELINE_DIR/group.baseline"
        chattr +i "$CREDENTIALS_BASELINE_DIR/group.baseline"
        log_ok "Created a baseline file for group."
    fi

    # Check if group file has been modified
    if ! diff -q "$CREDENTIALS_BASELINE_DIR/group.baseline" /etc/group > /dev/null 2>&1; then
        group_changed=true
        log_warn "group file has been modified."
        echo "------------Group File------------" >> "$SUMMARY_LOG"
        echo "[$HOST] group file has been modified at $(timestamp)" >> "$SUMMARY_LOG"
    else
        log_ok "group file matches baseline."
    fi
}

check_new_users() {
    log_info "Checking for new users..."
    
    if [ ! -f "$CREDENTIALS_BASELINE_DIR/passwd.baseline" ]; then
        log_warn "No baseline file found for new users check."
        return
    fi

    new_users=$(comm -13 <(cut -d: -f1 "$CREDENTIALS_BASELINE_DIR/passwd.baseline" | sort) <(cut -d: -f1 /etc/passwd | sort))
    if [ -n "$new_users" ]; then
        echo "------------New Users------------" >> "$SUMMARY_LOG"
        for user in $new_users; do
            log_warn "New user has been added: $user"
            echo "[$HOST] New user has been added: $user at $(timestamp)" >> "$SUMMARY_LOG"
        done
    else
        log_ok "No new users have been added."
    fi
}

check_modified_users() {
    log_info "Checking for modified users..."

    if [ ! -f "$CREDENTIALS_BASELINE_DIR/passwd.baseline" ]; then
        log_warn "No baseline file found for modified users check."
        return
    fi

    modified_found=false

    declare -A baseline_users current_users
    

    while IFS=: read -r user pass uid gid desc home shell; do
        baseline_users[$user]="$pass:$uid:$gid:$desc:$home:$shell"
    done < "$CREDENTIALS_BASELINE_DIR/passwd.baseline"

    while IFS=: read -r user pass uid gid desc home shell; do
        current_users[$user]="$pass:$uid:$gid:$desc:$home:$shell"
    done < /etc/passwd

    for user in "${!baseline_users[@]}"; do
        if [[ -n "${current_users[$user]}" ]]; then
            IFS=':' read -r b_pass b_uid b_gid b_desc b_home b_shell <<< "${baseline_users[$user]}"
            IFS=':' read -r c_pass c_uid c_gid c_desc c_home c_shell <<< "${current_users[$user]}"

            if [[ "$b_uid" != "$c_uid" ]]; then
                if [ "$modified_found" = false ]; then
                    echo "------------Modified Users------------" >> "$SUMMARY_LOG"
                    modified_found=true
                fi
                log_warn "UID change for $user: $b_uid -> $c_uid"
                event_log "UID-CHANGE" "UID change for $user: $b_uid -> $c_uid"
                echo "[$HOST] UID change for $user: $b_uid -> $c_uid at $(timestamp)" >> "$SUMMARY_LOG"
            fi

            if [[ "$b_gid" != "$c_gid" ]]; then
                if [ "$modified_found" = false ]; then
                    echo "------------Modified Users------------" >> "$SUMMARY_LOG"
                    modified_found=true
                fi
                log_warn "GID change for $user: $b_gid -> $c_gid"
                event_log "GID-CHANGE" "GID change for $user: $b_gid -> $c_gid"
                echo "[$HOST] GID change for $user: $b_gid -> $c_gid at $(timestamp)" >> "$SUMMARY_LOG"
            fi
            
            if [[ "$b_home" != "$c_home" ]]; then
                if [ "$modified_found" = false ]; then
                    echo "------------Modified Users------------" >> "$SUMMARY_LOG"
                    modified_found=true
                fi
                log_warn "Home directory change for $user: $b_home -> $c_home"
                event_log "HOME-CHANGE" "Home directory change for $user: $b_home -> $c_home"
                echo "[$HOST] Home directory change for $user: $b_home -> $c_home at $(timestamp)" >> "$SUMMARY_LOG"
            fi
            
            if [[ "$b_shell" != "$c_shell" ]]; then
                if [ "$modified_found" = false ]; then
                    echo "------------Modified Users------------" >> "$SUMMARY_LOG"
                    modified_found=true
                fi
                log_warn "Shell change for $user: $b_shell -> $c_shell"
                event_log "SHELL-CHANGE" "Shell change for $user: $b_shell -> $c_shell"
                echo "[$HOST] Shell change for $user: $b_shell -> $c_shell at $(timestamp)" >> "$SUMMARY_LOG"
            fi
        fi
    done

    if [ "$modified_found" = false ]; then
        log_ok "No modified users found."
    fi
}

check_deleted_users() {
    log_info "Checking for deleted users..."

    if [ ! -f "$CREDENTIALS_BASELINE_DIR/passwd.baseline" ]; then
        log_warn "No baseline file found for deleted users check."
        return
    fi

    deleted_users=$(comm -23 <(cut -d: -f1 "$CREDENTIALS_BASELINE_DIR/passwd.baseline" | sort) <(cut -d: -f1 /etc/passwd | sort))
    
    if [ -n "$deleted_users" ]; then
        echo "------------Deleted Users------------" >> "$SUMMARY_LOG"
        for user in $deleted_users; do
            log_warn "User has been deleted: $user"
            event_log "USER-DELETE" "User has been deleted: $user"
            echo "[$HOST] User has been deleted: $user at $(timestamp)" >> "$SUMMARY_LOG"
        done
    else
        log_ok "No users have been deleted."
    fi
}

check_uid_0_clones() {
    log_info "Checking for UID 0 clones..."
    if [ ! -f "$CREDENTIALS_BASELINE_DIR/passwd.baseline" ]; then
        log_warn "No baseline file found for UID 0 clones check."
        return
    fi
    clones_found=false
    
    # Store the results in a variable first
    uid_0_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
    
    # Process the results
    while read -r user; do
        if [ "$user" != "root" ]; then
            if [ "$clones_found" = false ]; then
                echo "------------UID 0 Clones------------" >> "$SUMMARY_LOG"
                clones_found=true
            fi
            log_warn "UID 0 clone detected: $user"
            event_log "UID-0-CLONE" "UID 0 clone detected: $user"
            echo "[$HOST] UID 0 clone detected: $user at $(timestamp)" >> "$SUMMARY_LOG"
        fi
    done <<< "$uid_0_users"
    
    if [ "$clones_found" = false ]; then
        log_ok "No UID 0 clones detected."
    fi
}

restore_credentials() {
    if [ "$passwd_changed" = true ] || [ "$shadow_changed" = true ] || [ "$group_changed" = true ]; then
        echo "------------Restored Credentials------------" >> "$SUMMARY_LOG"
    fi
    if [ "$passwd_changed" = true ]; then
        log_info "Restoring passwd file from baseline..."
        cp "$CREDENTIALS_BASELINE_DIR/passwd.baseline" /etc/passwd
        event_log "PASSWD-RESTORE" "Restored passwd file from baseline"
        echo "[$HOST] passwd file was restored due to a mismatch at $(timestamp)" >> "$SUMMARY_LOG"
    fi
    if [ "$shadow_changed" = true ]; then
        log_info "Restoring shadow file from baseline..."
        cp "$CREDENTIALS_BASELINE_DIR/shadow.baseline" /etc/shadow
        event_log "SHADOW-RESTORE" "Restored shadow file from baseline" 
        echo "[$HOST] shadow file was restored due to a mismatch at $(timestamp)" >> "$SUMMARY_LOG"
    fi
    if [ "$group_changed" = true ]; then
        log_info "Restoring group file from baseline..."
        cp "$CREDENTIALS_BASELINE_DIR/group.baseline" /etc/group
        event_log "GROUP-RESTORE" "Restored group file from baseline"
        echo "[$HOST] group file was restored due to a mismatch at $(timestamp)" >> "$SUMMARY_LOG"
    fi
    [ "$passwd_changed" = true ] || [ "$shadow_changed" = true ] || [ "$group_changed" = true ] && log_ok "Restored credentials from baseline."
}

update_baseline() {
    echo "------------Baseline Update------------" >> "$SUMMARY_LOG"
    echo "[$HOST] credential baseline files were updated at $(timestamp)" >> "$SUMMARY_LOG"
    
    # Define the pairs of baseline files and their real locations
    declare -A file_pairs=(
        ["$CREDENTIALS_BASELINE_DIR/passwd.baseline"]="/etc/passwd"
        ["$CREDENTIALS_BASELINE_DIR/shadow.baseline"]="/etc/shadow"
        ["$CREDENTIALS_BASELINE_DIR/group.baseline"]="/etc/group"
    )

    for baseline_file in "${!file_pairs[@]}"; do
        current_file="${file_pairs[$baseline_file]}"
        
        # Ensure baseline file exists
        if [ ! -f "$baseline_file" ]; then
            log_warn "No baseline file found at $baseline_file. Creating one now..."
            cp "$current_file" "$baseline_file"
            chattr +i "$baseline_file"
            log_ok "Created baseline file for $current_file"
            continue
        fi
        
        # Compare files
        if diff -u "$baseline_file" "$current_file" > /dev/null; then
            log_ok "No differences found. Baseline for $current_file already up to date." | tee -a "$SUMMARY_LOG"
        else
            log_warn "Differences detected in $current_file:"
            diff -u "$baseline_file" "$current_file"

            read -p "Overwrite existing baseline with current ruleset? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                cp "$current_file" "$baseline_file"
                log_ok "Baseline updated successfully."
                event_log "BASELINE-UPDATED" "User approved and updated the $current_file baseline"

                echo "[$HOST] Baseline for $current_file was updated via baseline mode at $(timestamp)" >> "$SUMMARY_LOG"
            else
                log_info "Baseline update canceled."
                event_log "BASELINE-CANCELED" "User canceled the $current_file baseline update"

                echo "[$HOST] Baseline update was canceled via baseline mode at $(timestamp)" >> "$SUMMARY_LOG"
            fi
        fi
    done
}

# ===== Default Mode: Check =====
if [[ "$MODE" == "check" ]]; then
    check_passwd
    check_shadow
    check_group
    check_new_users
    check_modified_users
    check_deleted_users
    check_uid_0_clones
    if [ "$AUTO_RESTORE_CREDENTIALS" = true ]; then
        restore_credentials
    fi
fi

# ===== Mode: Baseline =====
if [[ "$MODE" == "baseline" ]]; then
    update_baseline
fi
