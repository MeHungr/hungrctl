# config.sh
#
# This file stores configuration info for the various scripts
# meant to automate service uptime. This provides a central
# place to update all of the information.

# ===== Services to monitor =====
SERVICES=("apache2" "ssh" "cron")

# ===== Config files to check =====
CONFIG_FILES=("/etc/ssh/sshd_config" "/etc/apache2/apache2.conf")

# ===== Directories =====
CONTENT_DIRS=("/var/www/html")
OUTPUT_DIR="./output"

# ===== Webhooks =====
# Webhooks used for discord integration.
# See GENERAL_CONFIGURATION.DISCORD for more info
LOGGING_WEBHOOK_URL="https://discord.com/api/webhooks/1357498392812716082/LMiR71wIzo2wZWBaVGgz5fKOM5NRovAIRlg6bgjWbuLSfb8Ul4ZbUGv7M10J02iCojaF"
FIREWALL_WEBHOOK_URL="https://discord.com/api/webhooks/1357498435917320392/_dN25VLCS4xcC_Fr-aa-0cvL-BBhzM04k4-iJMkEdEedXjmOEqZYe4UKznCewpdgZZlh"
SERVICES_WEBHOOK_URL="https://discord.com/api/webhooks/1357540015390851084/yCGD831GobtmiILHlnFDFl5tXzkK4r7hBYSxVg0KfaKsAq3PmseBmzWlAGFXYhQckxOP"
COREUTILS_WEBHOOK_URL="https://discord.com/api/webhooks/1358728376109633647/2Afj4XMZV-OA3YV7_zTyQ3lKQhwyr5PRhXcvoTp4Y4I2uLGQohqvGENxqmdnuCDd7ga1"
LOGIN_PACKAGE_WEBHOOK_URL="https://discord.com/api/webhooks/1358985167062040737/oTSb0A6jURHDI8CMMow96AHS1-br9AXh_vgNzOiumZWVSN1fz1FnREko2VVZJcoI_7wv"
PASSWD_PACKAGE_WEBHOOK_URL="https://discord.com/api/webhooks/1358990134032334930/m9j0XBEypsrejpXZzt29evzPmhTutviipsSzoGUoJPMVXFcpURvPk1g_oonX8hgdBB6P"

# ===== GENERAL CONFIGURATION =====
AUTO_RESTART=true # Automatically restart services that are down
AUTO_RESTORE_CONFIG_FILES=true # Automatically restore config files from baseline if they're modified
AUTO_RESTORE_FIREWALL=true # Automatically restore firewall ruleset from baseline if it's modified
AUTO_REINSTALL_COREUTILS=true # Automatically reinstall coreutils if it's missing
AUTO_REINSTALL_LOGIN_PACKAGE=true # Automatically reinstall login package if it's missing
AUTO_REINSTALL_PASSWD_PACKAGE=true # Automatically reinstall passwd package if it's missing

DISCORD=true # Send messages to discord using webhooks? If yes, make sure you add the webhook links
