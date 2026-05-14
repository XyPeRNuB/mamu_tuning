#!/usr/bin/env bash
# ============================================================
#   Mamu Tuning Seedbox Installer v3.0
#   Supports: Debian 10/11/12 · Ubuntu 20.04/22.04/24.04
#   Arch: x86_64 · ARM64
# ============================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Colors ───────────────────────────────────────────────────
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; MAGENTA='\033[1;35m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

LOG_FILE="/root/mamu_install.log"
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

# ── Helpers ──────────────────────────────────────────────────
print_line() { printf "%b\n" "${DIM}============================================================${NC}"; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERR ]${NC} $1"; exit 1; }
section() { echo; print_line; echo -e "${MAGENTA}${BOLD}>> $1${NC}"; print_line; echo; }

ask_yes_no() {
    local prompt="$1" default="${2:-Y}" reply
    while true; do
        read -r -p "$(echo -e "${CYAN}${prompt}${NC} ")" reply
        reply="${reply:-$default}"
        case "$reply" in
            Y|y) return 0 ;;
            N|n) return 1 ;;
            *) echo -e "${RED}Please enter Y or N.${NC}" ;;
        esac
    done
}

# ── GitHub helpers ───────────────────────────────────────────
gh_asset_url() {
    local repo="$1" regex="$2"
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: mamu-seedbox-installer" \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"browser_download_url"' \
        | grep -E "$regex" \
        | cut -d'"' -f4 | head -1
}

download_file() {
    local url="$1" out="$2"
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 \
        -H "User-Agent: mamu-seedbox-installer" \
        -o "$out" "$url"
}

install_archive_binary() {
    local archive="$1" bin_name="$2" dest="${3:-/usr/local/bin/$2}"
    local tmpdir bin
    tmpdir="$(mktemp -d)"
    case "$archive" in
        *.zip)        unzip -q "$archive" -d "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
        *.tar.xz)     tar -xJf "$archive" -C "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
    esac
    bin="$(find "$tmpdir" -type f -name "$bin_name" | head -1 || true)"
    [[ -z "$bin" ]] && { rm -rf "$tmpdir"; return 1; }
    install -m 755 "$bin" "$dest" >> "$LOG_FILE" 2>&1
    rm -rf "$tmpdir"
}

# ── Detect arch ──────────────────────────────────────────────
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   ARCH_TAG="amd64"; ARCH_GH_RE='(amd64|x86_64)'; ARCH_ALT="x86_64" ;;
        aarch64|arm64)  ARCH_TAG="arm64"; ARCH_GH_RE='(arm64|aarch64)'; ARCH_ALT="aarch64" ;;
        *) err "Unsupported architecture: $(uname -m)" ;;
    esac
}

get_public_ip() {
    curl -4 -fsSL https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

# ── Root check ───────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root."
[[ -f /etc/os-release ]] || err "Cannot detect OS."
source /etc/os-release
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || err "Debian/Ubuntu only."

detect_arch

# ── Banner ───────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'

  ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗    ████████╗██╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗
  ████╗ ████║██╔══██╗████╗ ████║██║   ██║    ╚══██╔══╝██║   ██║████╗  ██║██║████╗  ██║██╔════╝
  ██╔████╔██║███████║██╔████╔██║██║   ██║       ██║   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
  ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║       ██║   ██║   ██║██║╚██╗██║██║██║╚██╗██║██║   ██║
  ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝

BANNER
echo -e "${NC}"
echo -e "  ${DIM}OS: $PRETTY_NAME | Arch: $ARCH_TAG${NC}"
echo ""

# ── Component selection ──────────────────────────────────────
section "Component Selection"

if ask_yes_no "Install qBittorrent? [Y/n]:" "Y"; then INSTALL_QBIT="yes"; else INSTALL_QBIT="no"; fi
if ask_yes_no "Install Qui (qBittorrent dashboard)? [Y/n]:" "Y"; then INSTALL_QUI="yes"; else INSTALL_QUI="no"; fi
if ask_yes_no "Install FileBrowser? [Y/n]:" "Y"; then INSTALL_FB="yes"; else INSTALL_FB="no"; fi
if ask_yes_no "Install autobrr? [Y/n]:" "Y"; then INSTALL_AUTOBRR="yes"; else INSTALL_AUTOBRR="no"; fi
if ask_yes_no "Install Media Tools (ffmpeg, aria2, mkbrr, etc)? [Y/n]:" "Y"; then INSTALL_MEDIA="yes"; else INSTALL_MEDIA="no"; fi
if ask_yes_no "Install rTorrent + ruTorrent? [y/N]:" "N"; then INSTALL_RTORRENT="yes"; else INSTALL_RTORRENT="no"; fi
if ask_yes_no "Install autoremove-torrents? [y/N]:" "N"; then INSTALL_AUTOREMOVE="yes"; else INSTALL_AUTOREMOVE="no"; fi
if ask_yes_no "Apply kernel tuning? [Y/n]:" "Y"; then DO_TUNING="yes"; else DO_TUNING="no"; fi
if ask_yes_no "Enable BBRv3? (recommended, requires reboot) [Y/n]:" "Y"; then ENABLE_BBR3="yes"; else ENABLE_BBR3="no"; fi
if ask_yes_no "Create 4GB swapfile? [Y/n]:" "Y"; then DO_SWAP="yes"; else DO_SWAP="no"; fi

# ── Credentials ──────────────────────────────────────────────
section "Configuration"

if [[ "$INSTALL_QBIT" == "yes" || "$INSTALL_FB" == "yes" || "$INSTALL_AUTOBRR" == "yes" ]]; then
    while true; do
        read -r -p "$(echo -e "${CYAN}Username:${NC} ")" username
        [[ -n "$username" ]] && break
        echo -e "${RED}Username cannot be empty.${NC}"
    done

    while true; do
        read -r -s -p "$(echo -e "${CYAN}Password (min 12 chars):${NC} ")" password; echo
        [[ ${#password} -ge 12 ]] && break
        echo -e "${RED}Password too short.${NC}"
    done
else
    username="root"
    password=""
fi

if [[ "$INSTALL_QBIT" == "yes" || "$INSTALL_AUTOBRR" == "yes" || "$INSTALL_AUTOREMOVE" == "yes" ]]; then
    while true; do
        read -r -p "$(echo -e "${CYAN}qBittorrent cache in MB [default: 2048]:${NC} ")" cache
        cache="${cache:-2048}"
        [[ "$cache" =~ ^[0-9]+$ ]] && break
        echo -e "${RED}Cache must be a number.${NC}"
    done

    read -r -p "$(echo -e "${CYAN}qBittorrent version [default: 4.6.7]:${NC} ")" qb_ver
    qb_ver="${qb_ver:-4.6.7}"
    lib_ver="v2.0.11"
else
    cache="2048"
    qb_ver="4.6.7"
    lib_ver="v2.0.11"
fi

# ── Summary ──────────────────────────────────────────────────
section "Installation Summary"
echo -e "${WHITE}${BOLD}Selected Components${NC}"
print_line
printf " %-28s : %s\n" "qBittorrent"          "$INSTALL_QBIT"
printf " %-28s : %s\n" "Qui"                  "$INSTALL_QUI"
printf " %-28s : %s\n" "FileBrowser"          "$INSTALL_FB"
printf " %-28s : %s\n" "autobrr"              "$INSTALL_AUTOBRR"
printf " %-28s : %s\n" "Media Tools"          "$INSTALL_MEDIA"
printf " %-28s : %s\n" "rTorrent + ruTorrent" "$INSTALL_RTORRENT"
printf " %-28s : %s\n" "autoremove-torrents"  "$INSTALL_AUTOREMOVE"
printf " %-28s : %s\n" "Kernel Tuning"        "$DO_TUNING"
printf " %-28s : %s\n" "BBRv3"                "$ENABLE_BBR3"
printf " %-28s : %s\n" "Swapfile"             "$DO_SWAP"
print_line
if [[ "$INSTALL_QBIT" == "yes" ]]; then
    printf " %-28s : %s\n" "Username"   "$username"
    printf " %-28s : %s\n" "qB Version" "$qb_ver"
    printf " %-28s : %s MB\n" "qB Cache" "$cache"
fi
echo
warn "Log file: $LOG_FILE"
echo
read -r -p "$(echo -e "${CYAN}Press Enter to continue...${NC}")"

# ============================================================
#  SYSTEM PREP
# ============================================================
section "System Preparation"

info "Updating package index..."
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
ok "System updated."

info "Installing base dependencies..."
apt-get install -y curl wget gnupg2 sudo lsb-release ca-certificates \
    unzip tar jq git ethtool net-tools ufw >> "$LOG_FILE" 2>&1
ok "Base dependencies installed."

# ============================================================
#  SWAP
# ============================================================
if [[ "$DO_SWAP" == "yes" ]]; then
    if ! swapon --show | grep -q '/swapfile' 2>/dev/null; then
        info "Creating 4GB swapfile..."
        fallocate -l 4G /swapfile >> "$LOG_FILE" 2>&1
        chmod 600 /swapfile
        mkswap /swapfile -q >> "$LOG_FILE" 2>&1
        swapon /swapfile >> "$LOG_FILE" 2>&1
        grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
        ok "4GB swapfile created."
    else
        warn "Swapfile already exists, skipping."
    fi
fi

# ============================================================
#  MAIN SEEDBOX INSTALL (qBit + autobrr + BBRv3)
# ============================================================
if [[ "$INSTALL_QBIT" == "yes" || "$INSTALL_AUTOBRR" == "yes" || "$INSTALL_AUTOREMOVE" == "yes" ]]; then
    section "Seedbox Installation"

    FLAG_B=""; FLAG_R=""; FLAG_NET=""
    [[ "$INSTALL_AUTOBRR" == "yes" ]]     && FLAG_B="-b"
    [[ "$INSTALL_AUTOREMOVE" == "yes" ]]  && FLAG_R="-r"
    [[ "$ENABLE_BBR3" == "yes" ]]         && FLAG_NET="-3"

    CMD_FLAGS="-u $username -p $password -c $cache -q $qb_ver -l $lib_ver $FLAG_B $FLAG_R $FLAG_NET"

    info "Running seedbox installer..."
    warn "This may take several minutes..."
    if ! bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) $CMD_FLAGS; then
        warn "Seedbox installer encountered an error. Check $LOG_FILE"
        if ! ask_yes_no "Continue with remaining installs? [y/N]:" "N"; then
            exit 1
        fi
    else
        ok "Seedbox installation complete."
    fi
fi

# ============================================================
#  KERNEL TUNING (our custom sysctl on top)
# ============================================================
if [[ "$DO_TUNING" == "yes" ]]; then
    section "Kernel Tuning"

    # Disable tuned if present (overrides sysctl on cloud VMs)
    systemctl stop tuned 2>/dev/null || true
    systemctl disable tuned 2>/dev/null || true

    # Fix bad @include
    sed -i '/@include/d' /etc/sysctl.conf 2>/dev/null || true

    # Load conntrack
    modprobe nf_conntrack 2>/dev/null || true
    echo "nf_conntrack" > /etc/modules-load.d/conntrack.conf

    # Patch Netcup sysctl override if present
    if [[ -f /etc/sysctl.d/99-nc-kernel.conf ]]; then
        cp /etc/sysctl.d/99-nc-kernel.conf /etc/sysctl.d/99-nc-kernel.conf.bak
        cat > /etc/sysctl.d/99-nc-kernel.conf << 'EOF'
vm.dirty_background_ratio = 10
vm.dirty_ratio = 40
kernel.watchdog_thresh = 20
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 524288 134217728
net.ipv4.tcp_wmem = 4096 524288 134217728
EOF
        warn "Patched cloud provider sysctl override."
    fi

    cat > /etc/sysctl.d/99-mamu-tuning.conf << 'EOF'
# ── Kernel scheduler ─────────────────────────────────────────
kernel.pid_max = 4194303
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000

# ── File system ───────────────────────────────────────────────
fs.file-max = 2097152
fs.nr_open = 2097152

# ── Memory ────────────────────────────────────────────────────
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 30
vm.dirty_expire_centisecs = 1000
vm.dirty_writeback_centisecs = 100
vm.vfs_cache_pressure = 50

# ── Network core ──────────────────────────────────────────────
net.core.rmem_default = 524288
net.core.rmem_max = 134217728
net.core.wmem_default = 524288
net.core.wmem_max = 134217728
net.core.optmem_max = 4194304
net.core.netdev_max_backlog = 100000
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 8000
net.core.somaxconn = 524288

# ── BBR + FQ (fallback if BBRv3 not installed) ────────────────
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ── TCP buffers ───────────────────────────────────────────────
net.ipv4.tcp_rmem = 4096 524288 134217728
net.ipv4.tcp_wmem = 4096 524288 134217728
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_limit_output_bytes = 1048576
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_syn_backlog = 524288
net.ipv4.tcp_max_tw_buckets = 10240
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_reordering = 10
net.ipv4.tcp_max_reordering = 300
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_frto = 0
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_comp_sack_delay_ns = 250000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# ── Conntrack ─────────────────────────────────────────────────
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10
EOF

    sysctl -p /etc/sysctl.d/99-mamu-tuning.conf >> "$LOG_FILE" 2>&1 || true

    # FD limits
    grep -q '1048576' /etc/security/limits.conf 2>/dev/null || \
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  65535
* hard nproc  65535
root soft nofile 1048576
root hard nofile 1048576
EOF

    if grep -q '^DefaultLimitNOFILE=' /etc/systemd/system.conf 2>/dev/null; then
        sed -i 's/^DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' /etc/systemd/system.conf
    else
        sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' /etc/systemd/system.conf
    fi
    systemctl daemon-reexec >> "$LOG_FILE" 2>&1 || true

    # I/O scheduler
    DISK=$(lsblk -d -o NAME,TYPE | awk '$2=="disk"{print $1}' | head -1)
    if [[ -n "$DISK" ]]; then
        echo mq-deadline > /sys/block/${DISK}/queue/scheduler 2>/dev/null || true
        echo 256 > /sys/block/${DISK}/queue/nr_requests 2>/dev/null || true
        cat > /etc/udev/rules.d/60-io-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="256"
EOF
    fi

    # Persistent sysctl service
    cat > /etc/systemd/system/mamu-sysctl.service << 'EOF'
[Unit]
Description=Mamu Tuning sysctl settings
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -p /etc/sysctl.d/99-mamu-tuning.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable mamu-sysctl.service >> "$LOG_FILE" 2>&1

    ok "Kernel tuning applied."
fi

# ============================================================
#  QUI
# ============================================================
if [[ "$INSTALL_QUI" == "yes" ]]; then
    section "Installing Qui"
    info "Downloading latest Qui..."

    QUI_URL="$(gh_asset_url "autobrr/qui" "linux.*(${ARCH_GH_RE}).*(deb|tar\.gz|tgz|zip)$" || true)"
    [[ -z "${QUI_URL:-}" ]] && QUI_URL="$(gh_asset_url "autobrr/qui" "${ARCH_GH_RE}.*(deb|tar\.gz|tgz|zip)$" || true)"

    if [[ -z "${QUI_URL:-}" ]]; then
        warn "Could not find Qui release for $ARCH_TAG — skipping."
    else
        TMPDIR="$(mktemp -d)"
        QUI_FILE="$TMPDIR/$(basename "${QUI_URL%%\?*}")"
        download_file "$QUI_URL" "$QUI_FILE" >> "$LOG_FILE" 2>&1

        case "$QUI_FILE" in
            *.deb) apt-get install -y "$QUI_FILE" >> "$LOG_FILE" 2>&1 ;;
            *.tar.gz|*.tgz|*.zip) install_archive_binary "$QUI_FILE" "qui" "/usr/local/bin/qui" ;;
        esac
        rm -rf "$TMPDIR"

        # Config
        mkdir -p /root/.config/qui
        cat > /root/.config/qui/config.toml << 'EOF'
# Mamu Tuning - Qui config
host = "0.0.0.0"
port = 7476
EOF
        chmod 700 /root/.config/qui
        chmod 600 /root/.config/qui/config.toml

        # Service
        cat > /etc/systemd/system/qui.service << 'EOF'
[Unit]
Description=Qui - qBittorrent Dashboard
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/qui serve
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >> "$LOG_FILE" 2>&1
        systemctl enable --now qui >> "$LOG_FILE" 2>&1 || true

        if command -v qui &>/dev/null; then
            ok "Qui installed and running on :7476"
        else
            warn "Qui install may have failed. Check $LOG_FILE"
        fi
    fi
fi


# ============================================================
#  RTORRENT + RUTORRENT
# ============================================================
if [[ "$INSTALL_RTORRENT" == "yes" ]]; then
    section "Installing rTorrent + ruTorrent"

    read -r -p "$(echo -e "${CYAN}ruTorrent web port [default: 8090]:${NC} ")" RT_PORT
    RT_PORT="${RT_PORT:-8090}"
    read -r -p "$(echo -e "${CYAN}rTorrent peer port [default: 49164]:${NC} ")" RT_PEER_PORT
    RT_PEER_PORT="${RT_PEER_PORT:-49164}"

    info "Installing rTorrent + PHP + Nginx..."
    apt-get install -y rtorrent nginx php-fpm php-cli php-curl php-json \
        php-mbstring php-xml php-zip php-gd apache2-utils >> "$LOG_FILE" 2>&1

    mkdir -p "/home/${username}/rtorrent/"{downloads,session,watch/load,watch/start}

    cat > "/home/${username}/.rtorrent.rc" << RTCONF
directory.default.set      = /home/${username}/rtorrent/downloads
session.path.set           = /home/${username}/rtorrent/session
schedule2 = watch_load,  10, 10, load.normal=/home/${username}/rtorrent/watch/load/*.torrent
schedule2 = watch_start, 10, 10, load.start=/home/${username}/rtorrent/watch/start/*.torrent
network.port_range.set          = ${RT_PEER_PORT}-${RT_PEER_PORT}
network.port_random.set         = no
network.max_open_sockets.set    = 999
network.max_open_files.set      = 600
network.receive_buffer.size.set = 128M
network.send_buffer.size.set    = 128M
network.xmlrpc.size_limit.set   = 20M
network.http.max_open.set       = 99
throttle.max_uploads.set        = 0
throttle.max_uploads.global.set = 500
throttle.min_peers.normal.set   = 1
throttle.max_peers.normal.set   = 300
throttle.min_peers.seed.set     = 0
throttle.max_peers.seed.set     = 100
trackers.numwant.set            = 100
network.scgi.open_local = /var/run/rtorrent/rtorrent.sock
schedule2 = chmod_scgi,0,0,"execute.nothrow=chmod,\"g+w,o=\",/var/run/rtorrent/rtorrent.sock"
system.umask.set = 0022
RTCONF

    chown -R "${username}:${username}" "/home/${username}/rtorrent"
    chown "${username}:${username}" "/home/${username}/.rtorrent.rc"

    mkdir -p /var/run/rtorrent
    chown "${username}:www-data" /var/run/rtorrent
    chmod 775 /var/run/rtorrent

    cat > /etc/systemd/system/rtorrent@.service << 'EOF'
[Unit]
Description=rTorrent for %i
After=network.target

[Service]
User=%i
ExecStartPre=/bin/mkdir -p /var/run/rtorrent
ExecStartPre=/bin/chown %i:www-data /var/run/rtorrent
ExecStart=/usr/bin/screen -d -m -S rtorrent /usr/bin/rtorrent
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    # Install screen
    apt-get install -y screen >> "$LOG_FILE" 2>&1

    # ruTorrent
    info "Installing ruTorrent..."
    rm -rf /var/www/rutorrent
    git clone --depth=1 https://github.com/Novik/ruTorrent.git /var/www/rutorrent >> "$LOG_FILE" 2>&1
    chown -R www-data:www-data /var/www/rutorrent

    cat > /var/www/rutorrent/conf/config.php << RUCONF
<?php
\$scgi_port = 0;
\$scgi_host = "unix:///var/run/rtorrent/rtorrent.sock";
\$XMLRPCMountPoint = "/RPC2";
\$topDirectory = "/home/${username}";
\$saveUploadedTorrents = true;
\$overwriteUploadedTorrents = false;
\$pathToExternals = array(
    "php"       => "/usr/bin/php",
    "curl"      => "/usr/bin/curl",
    "gzip"      => "/bin/gzip",
    "id"        => "/usr/bin/id",
    "stat"      => "/usr/bin/stat",
    "ffmpeg"    => "/usr/bin/ffmpeg",
    "mediainfo" => "/usr/bin/mediainfo",
);
RUCONF

    PHP_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1 || echo "/var/run/php/php-fpm.sock")
    htpasswd -bc /etc/nginx/.htpasswd "$username" "$password" >> "$LOG_FILE" 2>&1

    cat > /etc/nginx/sites-available/rutorrent << NGINXCONF
server {
    listen ${RT_PORT};
    server_name _;
    root /var/www/rutorrent;
    index index.html index.php;
    charset utf-8;
    client_max_body_size 100M;
    auth_basic "Mamu Tuning Seedbox";
    auth_basic_user_file /etc/nginx/.htpasswd;
    location / { try_files \$uri \$uri/ =404; }
    location ~ \.php\$ {
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
    location /RPC2 {
        scgi_pass unix:/var/run/rtorrent/rtorrent.sock;
        include scgi_params;
    }
}
NGINXCONF

    ln -sf /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/rutorrent
    rm -f /etc/nginx/sites-enabled/default
    nginx -t >> "$LOG_FILE" 2>&1 && systemctl restart nginx >> "$LOG_FILE" 2>&1

    systemctl daemon-reload
    systemctl enable "rtorrent@${username}" >> "$LOG_FILE" 2>&1
    systemctl start "rtorrent@${username}"

    ufw allow "${RT_PORT}/tcp" >> "$LOG_FILE" 2>&1
    ufw allow "${RT_PEER_PORT}/tcp" >> "$LOG_FILE" 2>&1

    ok "rTorrent + ruTorrent running on :${RT_PORT}"
fi

# ============================================================
#  MEDIA TOOLS
# ============================================================
if [[ "$INSTALL_MEDIA" == "yes" ]]; then
    section "Installing Media Tools"

    info "Installing base media packages..."
    apt-get install -y ffmpeg mediainfo curl aria2 mkvtoolnix mktorrent unzip wget >> "$LOG_FILE" 2>&1
    ok "Base media packages installed."

    # mkbrr
    info "Installing mkbrr..."
    MKBRR_URL="$(gh_asset_url "autobrr/mkbrr" "linux.*(${ARCH_GH_RE}).*\.deb$" || true)"
    if [[ -n "${MKBRR_URL:-}" ]]; then
        TMPDIR="$(mktemp -d)"
        download_file "$MKBRR_URL" "$TMPDIR/mkbrr.deb" >> "$LOG_FILE" 2>&1
        apt-get install -y "$TMPDIR/mkbrr.deb" >> "$LOG_FILE" 2>&1
        rm -rf "$TMPDIR"
        ok "mkbrr installed."
    else
        warn "Could not find mkbrr for $ARCH_TAG"
    fi

    # fastfetch
    info "Installing fastfetch..."
    FF_URL="$(gh_asset_url "fastfetch-cli/fastfetch" "linux.*(${ARCH_GH_RE}).*(deb|tar\.gz|tgz|zip)$" || true)"
    [[ -z "${FF_URL:-}" ]] && FF_URL="$(gh_asset_url "fastfetch-cli/fastfetch" "${ARCH_GH_RE}.*(deb|tar\.gz|tgz|zip)$" || true)"
    if [[ -n "${FF_URL:-}" ]]; then
        TMPDIR="$(mktemp -d)"
        FF_FILE="$TMPDIR/$(basename "${FF_URL%%\?*}")"
        download_file "$FF_URL" "$FF_FILE" >> "$LOG_FILE" 2>&1
        case "$FF_FILE" in
            *.deb) apt-get install -y "$FF_FILE" >> "$LOG_FILE" 2>&1 ;;
            *) install_archive_binary "$FF_FILE" "fastfetch" "/usr/local/bin/fastfetch" ;;
        esac
        rm -rf "$TMPDIR"
        ok "fastfetch installed."
    else
        warn "Could not find fastfetch for $ARCH_TAG"
    fi

    # Bento4
    info "Installing Bento4..."
    B4_VERSION="$(curl -fsSL https://www.bento4.com/downloads/ 2>/dev/null | sed -n 's/.*Version \([0-9][0-9.:-]*\).*/\1/p' | head -1 || true)"
    if [[ -n "${B4_VERSION:-}" ]]; then
        B4_FILE_VER="${B4_VERSION//./-}"
        B4_URL="https://www.bok.net/Bento4/binaries/Bento4-SDK-${B4_FILE_VER}.${ARCH_ALT}-unknown-linux.zip"
        TMPDIR="$(mktemp -d)"
        if download_file "$B4_URL" "$TMPDIR/bento4.zip" >> "$LOG_FILE" 2>&1; then
            unzip -o "$TMPDIR/bento4.zip" -d /tmp >> "$LOG_FILE" 2>&1
            cp /tmp/Bento4-SDK-*/bin/* /usr/local/bin/ >> "$LOG_FILE" 2>&1 || true
            rm -rf /tmp/Bento4-SDK-* "$TMPDIR"
            ok "Bento4 installed."
        else
            warn "Bento4 download failed — skipping."
            rm -rf "$TMPDIR"
        fi
    else
        warn "Could not determine Bento4 version — skipping."
    fi

    # Torrent creator script
    if [[ -n "${username:-}" ]]; then
        DL_PATH="/home/$username/qbittorrent/Downloads"
        mkdir -p "$DL_PATH"
        id "$username" &>/dev/null && chown "$username:$username" "$DL_PATH" >> "$LOG_FILE" 2>&1 || true
        if wget -q -O "$DL_PATH/main.py" https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py >> "$LOG_FILE" 2>&1; then
            chmod +x "$DL_PATH/main.py"
            id "$username" &>/dev/null && chown "$username:$username" "$DL_PATH/main.py" >> "$LOG_FILE" 2>&1 || true
            ok "Torrent creator saved to $DL_PATH/main.py"
        else
            warn "Could not download torrent creator script."
        fi
    fi

    ok "All media tools installed."
fi

# ============================================================
#  FILEBROWSER
# ============================================================
if [[ "$INSTALL_FB" == "yes" ]]; then
    section "Installing FileBrowser"
    info "Downloading FileBrowser..."
    if curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >> "$LOG_FILE" 2>&1; then
        ok "FileBrowser binary installed."

        cat > /etc/systemd/system/filebrowser.service << 'EOF'
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/filebrowser --database /root/filebrowser.db --root / --address 0.0.0.0 --port 808
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >> "$LOG_FILE" 2>&1

        # Init DB
        if [[ ! -f /root/filebrowser.db ]]; then
            timeout 5s /usr/local/bin/filebrowser --database /root/filebrowser.db --root / --port 808 >/dev/null 2>&1 || true
        fi

        if [[ -n "${password:-}" ]]; then
            /usr/local/bin/filebrowser users add "${username:-admin}" "$password" --perm.admin \
                --database /root/filebrowser.db >> "$LOG_FILE" 2>&1 || \
            /usr/local/bin/filebrowser users update "${username:-admin}" --password "$password" --perm.admin \
                --database /root/filebrowser.db >> "$LOG_FILE" 2>&1 || true
        fi

        systemctl enable --now filebrowser >> "$LOG_FILE" 2>&1 || true
        systemctl is-active --quiet filebrowser && ok "FileBrowser running on :808" || warn "FileBrowser may have failed to start."
    else
        warn "FileBrowser install failed."
    fi
fi

# ============================================================
#  FIREWALL
# ============================================================
section "Firewall"
info "Configuring UFW..."
ufw --force reset >> "$LOG_FILE" 2>&1
ufw default deny incoming >> "$LOG_FILE" 2>&1
ufw default allow outgoing >> "$LOG_FILE" 2>&1
ufw allow ssh >> "$LOG_FILE" 2>&1
ufw allow 8080/tcp >> "$LOG_FILE" 2>&1
ufw allow 45000/tcp >> "$LOG_FILE" 2>&1
ufw allow 45000/udp >> "$LOG_FILE" 2>&1
[[ "$INSTALL_QUI" == "yes" ]]  && ufw allow 7476/tcp >> "$LOG_FILE" 2>&1
[[ "$INSTALL_FB" == "yes" ]]   && ufw allow 808/tcp >> "$LOG_FILE" 2>&1
[[ "$INSTALL_AUTOBRR" == "yes" ]] && ufw allow 7474/tcp >> "$LOG_FILE" 2>&1
ufw --force enable >> "$LOG_FILE" 2>&1
ok "Firewall configured."

# ============================================================
#  FINAL SUMMARY
# ============================================================
section "Installation Complete"
PUBLIC_IP="$(get_public_ip)"

echo -e "${GREEN}${BOLD}All selected components have been installed.${NC}"
echo ""
printf " %-26s : %s\n" "Public IP"  "$PUBLIC_IP"
printf " %-26s : %s\n" "Username"   "${username:-N/A}"
[[ -n "${password:-}" ]] && printf " %-26s : %s\n" "Password" "$password"
echo ""

[[ "$INSTALL_QBIT" == "yes" ]]     && printf " %-26s : http://%s:8080\n"  "qBittorrent"  "$PUBLIC_IP"
[[ "$INSTALL_AUTOBRR" == "yes" ]]  && printf " %-26s : http://%s:7474\n"  "autobrr"      "$PUBLIC_IP"
[[ "$INSTALL_QUI" == "yes" ]]      && printf " %-26s : http://%s:7476\n"  "Qui"          "$PUBLIC_IP"
[[ "$INSTALL_RTORRENT" == "yes" ]] && printf " %-26s : http://%s:${RT_PORT:-8090}\n" "ruTorrent" "$PUBLIC_IP"
[[ "$INSTALL_FB" == "yes" ]]       && printf " %-26s : http://%s:808\n"   "FileBrowser"  "$PUBLIC_IP"

if [[ "$INSTALL_MEDIA" == "yes" ]]; then
    echo ""
    echo -e "${WHITE}${BOLD}Media Tools:${NC} ffmpeg, mediainfo, aria2, mkvtoolnix, mktorrent, mkbrr, fastfetch, Bento4"
    [[ -n "${username:-}" ]] && echo -e "${WHITE}${BOLD}Torrent Creator:${NC} /home/$username/qbittorrent/Downloads/main.py"
fi

if [[ "$DO_TUNING" == "yes" ]]; then
    echo ""
    echo -e "${WHITE}${BOLD}Kernel Tuning:${NC}"
    printf " %-26s : %s\n" "Congestion Control" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    printf " %-26s : %s\n" "rmem_max"           "$(sysctl -n net.core.rmem_max 2>/dev/null)"
    printf " %-26s : %s\n" "FD limit"           "$(ulimit -n)"
    [[ "$DO_SWAP" == "yes" ]] && printf " %-26s : %s\n" "Swap" "$(free -h | awk '/Swap/{print $2}')"
fi

echo ""
warn "Full log: $LOG_FILE"
[[ "$ENABLE_BBR3" == "yes" ]] && echo -e "${CYAN}BBRv3 selected — reboot required for full effect.${NC}"
print_line
echo -e "${GREEN}${BOLD}  Happy Racing! 🏁 — Mamu Tuning${NC}"
echo ""
exit 0
