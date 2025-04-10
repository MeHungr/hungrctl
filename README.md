# hungrctl – Modular Blue Team System Integrity Monitor

`hungrctl` is a modular, Bash-based system integrity and uptime monitoring suite built for blue team competitions and system hardening exercises. It provides lightweight service checks, anomaly detection, and baseline enforcement for critical system components like firewall rules, core services, login credentials, and cron jobs — all with optional auto-remediation and Discord webhook alerts.

---

## Features

- **Modular service checks** for credentials, core packages, firewall, and services
- **Baseline enforcement** for `/etc/passwd`, `/etc/shadow`, `/etc/group`, config files, and `nftables` rules
- **Auto-restore mode** to revert unexpected changes in credentials or firewall rules
- **Systemd service and timer checks** to ensure essential services are running
- **Checks for tampered or missing login/passwd packages**
- **Discord webhook integration** for sending alerts to multiple channels
- **Symbolic link** for ease of use—just run `hungrctl` as a command

---

## Directory Structure

```
hungrctl/
├── config.sh                  # Main config file (set webhooks, enable auto-restore, etc.)
├── init_hungrctl.sh           # Initialization script for setting up services and permissions
├── watchdog                   # Watchdog script triggered by systemd timer
├── lib/                       # Utility libraries (logging, env vars, Discord alerts)
│   ├── discord_send.sh
│   ├── env.sh
│   └── log.sh
├── service_checks/           # Individual modular system check scripts
│   ├── check_config.sh
│   ├── check_coreutils.sh
│   ├── check_credentials.sh
│   ├── check_cron.sh
│   ├── check_firewall.sh
│   ├── check_login_package.sh
│   ├── check_passwd_package.sh
│   └── check_services.sh
├── hungrctl                  # Main entry point script
```

---

## Setup

1. Clone the repository:

```bash
git clone https://github.com/MeHungr/hungrctl.git
cd hungrctl
```

2. Configure `config.sh`:

Edit the file to define:

- Webhook URLs per service check (e.g., `WEBHOOK_SERVICES`, `WEBHOOK_FIREWALL`)
- Boolean flags like `AUTO_RESTORE_CREDENTIALS=true`
- Baseline paths and summary directory

3.  Run the initialization script to set up hungrctl as a service:

```bash
sudo ./init_hungrctl.sh
```

This sets secure permissions, installs the `hungrctl` and watchdog services and timers, and locks everything down with `chattr +i`. The watchdog runs independently to verify `hungrctl` is still present and functional, reinitializing it if tampering is detected. The services are automatically enabled and started.

---

## Usage

The `hungrctl` script can be run manually on top of the automated service. Check the help message for more info `hungrctl -h`. The script accepts modular flags to run specific checks or create baselines:

### Common Flags

| Flag                  | Description                                      |
| --------------------- | ------------------------------------------------ |
| `-a`, `--all`         | Run all checks                                   |
| `-c`, `--config`      | Check config file integrity                      |
| `-d`, `--credentials` | Check credentials (passwd, shadow, group)        |
| `-f`, `--firewall`    | Check nftables firewall ruleset                  |
| `-l`, `--login`       | Check login-related packages                     |
| `-o`, `--cron`        | Check cron jobs                                  |
| `-p`, `--passwd`      | Check passwd-related packages                    |
| `-s`, `--services`    | Check systemd services                           |
| `-u`, `--coreutils`   | Check core system utilities                      |
| `-m`, `--mode`        | Choose `check` or `baseline` mode                |
| `-r`, `--run`         | Run a command before the check (e.g. apply rule) |
| `-n`, `--no-summary`  | Suppress end-of-check summary output             |
| `-h`, `--help`        | Show help message                                |

### Examples

Run all checks:

```bash
sudo ./hungrctl --all
sudo ./hungrctl
```

Baseline credentials and firewall:

```bash
sudo ./hungrctl --mode baseline --credentials --firewall
sudo ./hungrctl --credentials --firewall baseline
```

Update firewall baseline after applying a rule:

```bash
sudo ./hungrctl --firewall --run 'nft add rule inet filter input tcp dport 80 accept' --mode baseline
```

Run service and config checks in default (check) mode:

```bash
sudo ./hungrctl --services --config
```

---

## Webhook Alerting

Each check script sends alert summaries to Discord using per-check webhooks defined in `config.sh`. Webhook variables follow the format `NAME_WEBHOOK_URL`, where `NAME` corresponds to the service or check being monitored.

Example webhook variables:

- `SERVICES_WEBHOOK_URL`
- `CREDENTIALS_WEBHOOK_URL`
- `FIREWALL_WEBHOOK_URL`
- `CRON_WEBHOOK_URL`
- `COREUTILS_WEBHOOK_URL`

You can route each check to a different Discord channel by assigning each variable a different webhook URL.

---

## Auto-Remediation

To enable automatic restores or restarts, set these in your `config.sh`:

```bash
AUTO_RESTORE_CREDENTIALS=true
AUTO_RESTORE_FIREWALL=true
AUTO_RESTART=true
```

---

## Compatibility

- OS: Linux (tested on Debian)
- Requires: `bash`, `systemctl`, `nft`, `diff`, `awk`, `chattr`, `jq`&#x20;

Ideal for environments where binaries may be compromised and minimal tooling is preferred.

---

## Author

**MeHungr**\
GitHub: [github.com/MeHungr](https://github.com/MeHungr)
