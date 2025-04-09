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
            ;;
        rhel|centos|fedora|arch|manjaro)
            # Modify /usr/bin/ls
            cp /usr/bin/ls /usr/bin/ls.bak
            echo "#!/bin/bash" > /usr/bin/ls
            echo "echo 'This is a broken ls command'" >> /usr/bin/ls
            chmod +x /usr/bin/ls
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
            ;;
        rhel|centos|fedora|arch|manjaro)
            # Modify /usr/bin/login
            cp /usr/bin/login /usr/bin/login.bak
            echo "#!/bin/bash" > /usr/bin/login
            echo "echo 'This is a broken login command'" >> /usr/bin/login
            chmod +x /usr/bin/login
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
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            log_info "Stopped service: $service"
        fi
    done
    log_ok "Services broken successfully"
}

# ===== Function to break firewall =====
break_firewall() {
    log_info "Breaking firewall..."
    
    # Create a temporary nftables ruleset
    cat > /tmp/broken_firewall.nft << 'EOF'
table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport { 22, 80, 443, 3389, 445, 23 } accept
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
    
    # Create a test user with UID 0 (root clone)
    useradd -u 0 -o -g root -G root -d /root -s /bin/bash test_root_clone 2>/dev/null || true
    
    # Modify passwd file
    cp /etc/passwd /etc/passwd.bak
    echo "test_user:x:1001:1001:Test User:/home/test_user:/bin/bash" >> /etc/passwd
    
    # Modify shadow file
    cp /etc/shadow /etc/shadow.bak
    echo "test_user::19110:0:99999:7:::" >> /etc/shadow
    
    # Modify group file
    cp /etc/group /etc/group.bak
    echo "test_group:x:1001:test_user" >> /etc/group
    
    log_ok "Credential checks broken successfully"
}

# ===== Function to restore all =====
restore_all() {
    log_info "Restoring all broken components..."
    
    # Restore coreutils
    case "$DISTRO" in
        ubuntu|debian)
            [ -f /bin/ls.bak ] && mv /bin/ls.bak /bin/ls
            ;;
        rhel|centos|fedora|arch|manjaro)
            [ -f /usr/bin/ls.bak ] && mv /usr/bin/ls.bak /usr/bin/ls
            ;;
    esac
    
    # Restore login package
    case "$DISTRO" in
        ubuntu|debian)
            [ -f /bin/login.bak ] && mv /bin/login.bak /bin/login
            ;;
        rhel|centos|fedora|arch|manjaro)
            [ -f /usr/bin/login.bak ] && mv /usr/bin/login.bak /usr/bin/login
            ;;
    esac
    
    # Restore passwd package
    case "$DISTRO" in
        ubuntu|debian|rhel|centos|fedora|arch|manjaro)
            [ -f /usr/bin/passwd.bak ] && mv /usr/bin/passwd.bak /usr/bin/passwd
            ;;
    esac
    
    # Restore services
    for service in "${SERVICES[@]}"; do
        systemctl start "$service" 2>/dev/null || true
    done
    
    # Restore firewall
    nft flush ruleset
    nft add table inet filter
    nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
    nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
    nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
    
    # Restore config files
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "${file}.bak" ]; then
            mv "${file}.bak" "$file"
            log_info "Restored config file: $file"
        fi
    done
    
    # Restore credential checks
    # Remove test user
    userdel -f test_root_clone 2>/dev/null || true
    userdel -f test_user 2>/dev/null || true
    groupdel test_group 2>/dev/null || true
    
    # Restore credential files
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
        ;;
    "restore")
        restore_all
        ;;
    *)
        echo "Usage: $0 [break|restore]"
        exit 1
        ;;
esac 