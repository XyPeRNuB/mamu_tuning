<div align="center">

```
  ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗    ████████╗██╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗
  ████╗ ████║██╔══██╗████╗ ████║██║   ██║    ╚══██╔══╝██║   ██║████╗  ██║██║████╗  ██║██╔════╝
  ██╔████╔██║███████║██╔████╔██║██║   ██║       ██║   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
  ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║       ██║   ██║   ██║██║╚██╗██║██║██║╚██╗██║██║   ██║
  ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝
```

**Seedbox Installer v4.0**

A modular, interactive seedbox installer for Debian/Ubuntu with kernel tuning tested specifically on Netcup ARM64 — built for private tracker racing.

[![OS](https://img.shields.io/badge/OS-Debian%2011%2F12%20%7C%20Ubuntu%2020.04%2B-blue?style=flat-square)](https://debian.org)
[![Arch](https://img.shields.io/badge/Arch-ARM64%20%7C%20x86__64-green?style=flat-square)](https://github.com/XyPeRNuB/mamu_tuning)
[![Version](https://img.shields.io/badge/Version-4.0-cyan?style=flat-square)](https://github.com/XyPeRNuB/mamu_tuning)

</div>

---

## 🚀 Quick Install

```bash
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

Or with wget:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

> Run as **root**. Supports Debian 11/12 and Ubuntu 20.04/22.04/24.04 on ARM64 and x86_64.

---

## 📺 Interface

Swizzin-style interactive UI. Navigate with arrow keys, Space to select, Enter to confirm.

```
┌─────────────────────────────────────────────────────────────┐
│                   Mamu Tuning — Apps                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Select apps to install:                                    │
│  (Space to select, Enter to confirm)                        │
│                                                             │
│  [ ] qbt          qBittorrent-nox                           │
│  [ ] rtorrent     rTorrent + ruTorrent                      │
│  [ ] autobrr      autobrr                                   │
│  [ ] jellyfin     Jellyfin                                  │
│  [ ] filebrowser  FileBrowser                               │
│  [ ] qui          Qui Dashboard                             │
│  [ ] media        Media Tools                               │
│  [ ] tuning       Kernel Tuning                             │
│  [ ] bbr3         BBRv3                                     │
│  [ ] swap         4GB Swapfile                              │
│                                                             │
│               <Ok>              <Cancel>                    │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│              What do you want to do?                        │
│                                                             │
│  (*) Install / Add new apps                                 │
│  ( ) Uninstall / Remove apps                                │
│                                                             │
│               <Ok>              <Cancel>                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Apps

| App | Description | Default Port |
|-----|-------------|-------------|
| **qBittorrent-nox** | Static build, pre-tuned for private trackers | WebUI: `8080` · Peer: `45000` |
| **rTorrent + ruTorrent** | rTorrent with ruTorrent web UI | `8090` |
| **autobrr** | Autodl / torrent racing automation | `7474` |
| **Jellyfin** | Open source media server | `8096` |
| **FileBrowser** | Web-based file manager | `808` |
| **Qui** | qBittorrent unified dashboard | `7476` |

> All ports are configurable during install. Re-run anytime to add or remove apps.

---

## 🛠️ Media Tools

When Media Tools is selected, the following get installed automatically:

- **ffmpeg** — video processing
- **mediainfo** — file information
- **aria2** — fast multi-connection downloader
- **mkvtoolnix** — MKV file tools
- **mktorrent** — torrent creator
- **mkbrr** — fast torrent creator for racing
- **fastfetch** — system info
- **Bento4** — MP4/streaming tools
- **Torrent creator script** — saved to `/home/user/qbittorrent/Downloads/main.py`

---

## ⚙️ Kernel Tuning

Tuning values tested on **Netcup ARM64 Neoverse-N1** — not generic internet copy-paste.

### What we found and fixed
- **RPS was disabled** — all packets going to one core. Fixed: enabled across all 6 cores
- **rwnd_limited at 54%** — receive window was bottlenecking throughput. Fixed: buffer sizes calculated from actual BDP (254MB/s × 300ms RTT)
- **reordering:204** — very high packet reordering observed. Fixed: increased reordering tolerance

### Network
| Setting | Value | Why |
|---------|-------|-----|
| Congestion control | BBR | Aggressive throughput |
| Queue discipline | FQ | Fair packet pacing |
| rmem_max / wmem_max | 128MB | Sized for 250MB/s+ lines |
| tcp_rmem / tcp_wmem | 4K → 128MB | Auto-scales to line speed |
| tcp_notsent_lowat | 16KB | Send pieces immediately |
| tcp_reordering | 16 | Matches observed reordering on Netcup |
| rps_sock_flow_entries | 196608 | RFS flow steering |
| netdev_max_backlog | 100,000 | Handle packet bursts |
| somaxconn | 524,288 | High connection queue |
| tcp_fastopen | 3 | Faster connection setup |
| tcp_tw_reuse | enabled | Reuse TIME_WAIT sockets |

### Multiqueue RPS/RFS/XPS
All 6 network queues are configured to spread traffic across all CPU cores:
- **RPS** — steers incoming packets across cores (was disabled by default)
- **RFS** — keeps related flows on the same core for cache efficiency
- **XPS** — steers outgoing packets to matching TX queue

Persists across reboots via systemd service.

### System
| Setting | Value | Effect |
|---------|-------|--------|
| File descriptors | 2,097,152 | Handle thousands of open torrents |
| pid_max | 4,194,303 | More processes |
| I/O scheduler | mq-deadline | Optimal for virtio disk |
| vm.swappiness | 10 | Keep hot data in RAM |
| Swapfile | 4GB | OOM protection |
| tuned daemon | disabled | Prevents cloud provider sysctl override |

---

## 🔧 qBittorrent Config

Pre-configured for private tracker racing out of the box.

| Setting | Value | Why |
|---------|-------|-----|
| Async IO threads | = CPU cores | Max parallel disk IO |
| Disk cache | 2048 MB | Fast piece access |
| Protocol | TCP only | Max bandwidth for private trackers |
| Max connections | 500 | Racing optimized |
| Max conn/torrent | 100 | Racing optimized |
| Upload slots | 20 | Balanced peer turnover |
| Upload slots/torrent | 10 | Balanced peer turnover |
| DHT / PeX / LSD | Disabled | Private tracker only |
| Send buffer watermark | 15360 | Proven racing value |
| Speed limits | Unlimited | Full bandwidth |
| Peer turnover | enabled | Replace slow peers aggressively |
| Announce to all tiers | enabled | Faster tracker announces |

---

## 🖥️ Supported Platforms

| OS | Versions | ARM64 | x86_64 |
|----|----------|-------|--------|
| Debian | 11, 12 | ✅ | ✅ |
| Ubuntu | 20.04, 22.04, 24.04 | ✅ | ✅ |

---

## 📋 Requirements

- Fresh VPS or dedicated server
- Root access
- Minimum 2GB RAM (4GB+ recommended for racing)
- Minimum 20GB disk space

---

## 🔁 Re-running the Installer

Safe to run multiple times. Already installed apps show `[INSTALLED]`. Use Uninstall mode to remove apps.

```bash
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

---

## 📁 File Structure

```
/etc/sysctl.d/99-mamu-tuning.conf         ← kernel tuning (tested values)
/etc/systemd/system/mamu-sysctl.service   ← apply sysctl on boot
/etc/systemd/system/mamu-multiqueue.service ← RPS/RFS/XPS on boot
/etc/mamu-multiqueue.sh                   ← multiqueue setup script
/etc/udev/rules.d/60-io-scheduler.rules   ← I/O scheduler persistence
/home/<user>/.config/qBittorrent/         ← qBit config
/home/<user>/rtorrent/                    ← rTorrent data
/root/.config/qui/config.toml             ← Qui config
/root/filebrowser.db                      ← FileBrowser database
/root/mamu_install.log                    ← install log
```

---

<div align="center">
Happy Racing 🏁
</div>
