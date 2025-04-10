#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/env.sh"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

# ===== Function to break coreutils =====
break_coreutils() {
    log_info "Breaking coreutils..."
    case "$DISTRO" in
        ubuntu|debian)
            # Modify /bin/ls
            cp /bin/ls /bin/ls.bak
            echo "#!/bin/bash" > /bin/ls
            echo "echo 'This is a broken ls command'" >> /bin/ls
            chmod +x /bin/ls
            
            # Modify other coreutils
            for cmd in cat cp mv rm chmod chown; do
                if [ -f "/bin/$cmd" ]; then
                    cp "/bin/$cmd" "/bin/${cmd}.bak"
                    echo "#!/bin/bash" > "/bin/$cmd"
                    echo "echo 'This is a broken $cmd command'" >> "/bin/$cmd"
                    chmod +x "/bin/$cmd"
                fi
            done
            ;;
        rhel|centos|fedora|arch|manjaro)
            # Modify /usr/bin/ls
            cp /usr/bin/ls /usr/bin/ls.bak
            echo "#!/bin/bash" > /usr/bin/ls
            echo "echo 'This is a broken ls command'" >> /usr/bin/ls
            chmod +x /usr/bin/ls
            
            # Modify other coreutils
            for cmd in cat cp mv rm chmod chown; do
                if [ -f "/usr/bin/$cmd" ]; then
                    cp "/usr/bin/$cmd" "/usr/bin/${cmd}.bak"
                    echo "#!/bin/bash" > "/usr/bin/$cmd"
                    echo "echo 'This is a broken $cmd command'" >> "/usr/bin/$cmd"
                    chmod +x "/usr/bin/$cmd"
                fi
            done
            ;;
    esac
    log_ok "Coreutils broken successfully"
}

# ===== Function to break login package =====
break_login_package() {
    log_info "Breaking login package..."
    case "$DISTRO" in
        ubuntu|debian)
            # Modify /bin/login
            cp /bin/login /bin/login.bak
            echo "#!/bin/bash" > /bin/login
            echo "echo 'This is a broken login command'" >> /bin/login
            chmod +x /bin/login
            
            # Modify PAM configuration
            cp /etc/pam.d/login /etc/pam.d/login.bak
            echo "# Broken PAM configuration" > /etc/pam.d/login
            echo "auth sufficient pam_permit.so" >> /etc/pam.d/login
            ;;
        rhel|centos|fedora|arch|manjaro)
            # Modify /usr/bin/login
            cp /usr/bin/login /usr/bin/login.bak
            echo "#!/bin/bash" > /usr/bin/login
            echo "echo 'This is a broken login command'" >> /usr/bin/login
            chmod +x /usr/bin/login
            
            # Modify PAM configuration
            cp /etc/pam.d/login /etc/pam.d/login.bak
            echo "# Broken PAM configuration" > /etc/pam.d/login
            echo "auth sufficient pam_permit.so" >> /etc/pam.d/login
            ;;
    esac
    log_ok "Login package broken successfully"
}

# ===== Function to break passwd package =====
break_passwd_package() {
    log_info "Breaking passwd package..."
    case "$DISTRO" in
        ubuntu|debian)
            # Modify /usr/bin/passwd
            cp /usr/bin/passwd /usr/bin/passwd.bak
            echo "#!/bin/bash" > /usr/bin/passwd
            echo "echo 'This is a broken passwd command'" >> /usr/bin/passwd
            chmod +x /usr/bin/passwd
            ;;
        rhel|centos|fedora|arch|manjaro)
            # Modify /usr/bin/passwd
            cp /usr/bin/passwd /usr/bin/passwd.bak
            echo "#!/bin/bash" > /usr/bin/passwd
            echo "echo 'This is a broken passwd command'" >> /usr/bin/passwd
            chmod +x /usr/bin/passwd
            ;;
    esac
    log_ok "Passwd package broken successfully"
}

# ===== Function to break services =====
break_services() {
    log_info "Breaking services..."
    
    # Stop critical services
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            log_info "Stopped and disabled service: $service"
        fi
    done
    log_ok "Services broken successfully"
}

# ===== Function to break firewall =====
break_firewall() {
    log_info "Breaking firewall..."
    
    # Disable firewall
    systemctl stop nftables
    systemctl disable nftables
    
    # Create a permissive nftables ruleset
    cat > /tmp/broken_firewall.nft << 'EOF'
table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport { 22, 80, 443, 3389, 445, 23, 21, 25, 53, 110, 143, 993, 995, 3306, 5432, 27017 } accept
    }
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

    # Apply the broken ruleset
    nft -f /tmp/broken_firewall.nft
    rm /tmp/broken_firewall.nft
    
    log_ok "Firewall broken successfully"
}

# ===== Function to break config files =====
break_config_files() {
    log_info "Breaking config files..."
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$file" ]; then
            # Create a backup
            cp "$file" "${file}.bak"
            # Create a broken version
            echo "# This is a broken config file" > "$file"
            echo "# Original content backed up to ${file}.bak" >> "$file"
            log_info "Modified config file: $file (backup at ${file}.bak)"
        fi
    done
    
    log_ok "Config files broken successfully"
}

# ===== Function to break credential checks =====
break_credential_checks() {
    log_info "Breaking credential checks..."
    
    # Create test users with various issues
    useradd -u 0 -o -g root -G root -d /root -s /bin/bash test_root_clone 2>/dev/null || true
    useradd -u 1 -o -g root -G root -d /root -s /bin/bash test_root_clone2 2>/dev/null || true
    useradd -u 1001 -g 1001 -d /home/test_user -s /bin/bash test_user 2>/dev/null || true
    
    # Modify passwd file
    cp /etc/passwd /etc/passwd.bak
    echo "test_user:x:1001:1001:Test User:/home/test_user:/bin/bash" >> /etc/passwd
    echo "test_user2:x:1002:1002:Test User 2:/home/test_user2:/bin/bash" >> /etc/passwd
    
    # Modify shadow file
    cp /etc/shadow /etc/shadow.bak
    echo "test_user::19110:0:99999:7:::" >> /etc/shadow
    echo "test_user2::19110:0:99999:7:::" >> /etc/shadow
    
    # Modify group file
    cp /etc/group /etc/group.bak
    echo "test_group:x:1001:test_user" >> /etc/group
    echo "test_group2:x:1002:test_user2" >> /etc/group
    
    # Create world-writable home directories
    mkdir -p /home/test_user /home/test_user2
    chmod 777 /home/test_user /home/test_user2
    
    # Create world-writable files
    touch /home/test_user/world_writable.txt /home/test_user2/world_writable.txt
    chmod 666 /home/test_user/world_writable.txt /home/test_user2/world_writable.txt
    
    log_ok "Credential checks broken successfully"
}

# ===== Function to break cron jobs =====
break_cron_jobs() {
    log_info "Breaking cron jobs..."
    
    # Create world-writable cron directories
    mkdir -p /etc/cron.d/test_cron
    chmod 777 /etc/cron.d/test_cron
    
    # Create world-writable cron files
    echo "* * * * * root echo 'This is a broken cron job'" > /etc/cron.d/test_cron/broken_cron
    chmod 666 /etc/cron.d/test_cron/broken_cron
    
    # Create cron jobs with insecure permissions
    echo "* * * * * root chmod 777 /tmp" > /etc/cron.d/insecure_cron
    chmod 644 /etc/cron.d/insecure_cron
    
    log_ok "Cron jobs broken successfully"
}

# ===== Function to restore all =====
restore_all() {
    log_info "Restoring all broken components..."
    
    # Restore coreutils
    case "$DISTRO" in
        ubuntu|debian)
            for cmd in ls cat cp mv rm chmod chown; do
                [ -f "/bin/${cmd}.bak" ] && mv "/bin/${cmd}.bak" "/bin/$cmd"
            done
            ;;
        rhel|centos|fedora|arch|manjaro)
            for cmd in ls cat cp mv rm chmod chown; do
                [ -f "/usr/bin/${cmd}.bak" ] && mv "/usr/bin/${cmd}.bak" "/usr/bin/$cmd"
            done
            ;;
    esac
    
    # Restore login package
    case "$DISTRO" in
        ubuntu|debian)
            [ -f /bin/login.bak ] && mv /bin/login.bak /bin/login
            [ -f /etc/pam.d/login.bak ] && mv /etc/pam.d/login.bak /etc/pam.d/login
            ;;
        rhel|centos|fedora|arch|manjaro)
            [ -f /usr/bin/login.bak ] && mv /usr/bin/login.bak /usr/bin/login
            [ -f /etc/pam.d/login.bak ] && mv /etc/pam.d/login.bak /etc/pam.d/login
            ;;
    esac
    
    # Restore passwd package
    case "$DISTRO" in
        ubuntu|debian|rhel|centos|fedora|arch|manjaro)
            [ -f /usr/bin/passwd.bak ] && mv /usr/bin/passwd.bak /usr/bin/passwd
            [ -f /etc/pam.d/passwd.bak ] && mv /etc/pam.d/passwd.bak /etc/pam.d/passwd
            ;;
    esac
    
    # Restore services
    for service in "${SERVICES[@]}"; do
        systemctl enable --now"$service" 2>/dev/null || true
    done
    
    # Restore firewall
    nft flush ruleset
    nft add table inet filter
    nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
    nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
    nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
    systemctl enable --now nftables
    
    # Restore config files
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "${file}.bak" ]; then
            mv "${file}.bak" "$file"
            log_info "Restored config file: $file"
        fi
    done
    
    # Restore credential checks
    userdel -f test_root_clone 2>/dev/null || true
    userdel -f test_root_clone2 2>/dev/null || true
    userdel -f test_user 2>/dev/null || true
    userdel -f test_user2 2>/dev/null || true
    groupdel test_group 2>/dev/null || true
    groupdel test_group2 2>/dev/null || true
    
    [ -f /etc/passwd.bak ] && mv /etc/passwd.bak /etc/passwd
    [ -f /etc/shadow.bak ] && mv /etc/shadow.bak /etc/shadow
    [ -f /etc/group.bak ] && mv /etc/group.bak /etc/group
    
    log_ok "All components restored successfully"
}

# ===== Main script =====
case "$1" in
    "break")
        break_coreutils
        break_login_package
        break_passwd_package
        break_services
        break_firewall
        break_config_files
        break_credential_checks
        break_cron_jobs
        ;;
    "restore")
        restore_all
        ;;
    *)
        echo "Usage: $0 [break|restore]"
        exit 1
        ;;
esac 