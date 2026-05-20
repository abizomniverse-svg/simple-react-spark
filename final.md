# Achme Enterprise Private Cloud Server - Complete Architecture

## One-Click Cloud Server Setup

Your Windows PC is now a professional-grade private company server. Double-click `startserver.bat` and your entire enterprise infrastructure launches automatically.

---

## Quick Start

1. **Double-click `startserver.bat`**
2. **Press `1`** to start all services
3. **Open browser** → `https://achme.com`

Done. Your server is live.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR WINDOWS PC = CLOUD SERVER               │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Nginx     │───▶│    PM2      │───▶│    MySQL    │         │
│  │ Port 80/443 │    │ Port 5000   │    │ Port 3306   │         │
│  │ SSL/TLS     │    │ Node.js API │    │ Database    │         │
│  └──────┬──────┘    └─────────────┘    └─────────────┘         │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────────┐    ┌──────────────────────────┐         │
│  │ React Frontend   │    │ Cloudflare Tunnel         │         │
│  │ (Static Files)   │    │ (Secure Remote Access)    │         │
│  └──────────────────┘    └────────────┬─────────────┘         │
│                                       │                       │
└───────────────────────────────────────┼───────────────────────┘
                                        │
                               ┌────────▼──────────┐
                               │  Anywhere in World │
                               │  https://domain    │
                               └───────────────────┘
```

### Service Stack

| Component | Port | Role |
|-----------|------|------|
| **Nginx** | 80/443 | Reverse proxy, SSL termination, static file serving |
| **Node.js + Express** | 5000 | Backend API (managed by PM2, fork mode) |
| **MySQL** | 3306 | Database (Windows service, auto-starts on boot) |
| **Cloudflare Tunnel** | Outbound only | Secure remote access, zero port forwarding |
| **PM2** | - | Process manager, auto-restart on crash |
| **Watchdog** | - | Health monitoring, self-healing recovery |

---

## Control Panel

`startserver.bat` opens an interactive menu:

```
[1] START SERVER     - Launch Nginx + Backend + Monitors
[2] STOP SERVER      - Graceful shutdown of all services
[3] SETUP CLOUDFLARE - Enable worldwide remote access
[4] SETUP AUTO-START - Auto-launch on Windows boot
[5] VIEW STATUS      - Check all services health
[6] VIEW LOGS        - Open server log files
[0] EXIT
```

---

## How Others Access Your Local Domain

### Same Office Network (LAN)
- Devices on same Wi-Fi → `https://achme.com` works automatically
- Hosts file maps `achme.com` → your PC's LAN IP

### Remote Access (Anywhere in World)

**Method 1: Cloudflare Tunnel (Recommended)**
- No port forwarding needed
- No router configuration
- Works behind CGNAT
- Free SSL from Cloudflare
- Setup: Menu Option 3 → paste token → done

**Method 2: Tailscale VPN**
- Install Tailscale on server + client devices
- Join same network
- Access via `https://achme.com`

### Quick Decision Table

| Scenario | Method | VPN Needed? | Cert Install? |
|----------|--------|:-----------:|:-------------:|
| Same office | Hosts/DNS | No | Yes |
| Remote workers | Tailscale | Yes | Yes |
| Clients/public | Cloudflare Tunnel | No | No |

---

## Auto-Start on Boot

Your server automatically starts when Windows turns on:

1. **Windows Task Scheduler** - Primary (runs as system, 1 min delay)
2. **Startup Folder** - Fallback (runs on user login)

Configure via: `startserver.bat` → Option 4

### Boot Sequence

```
PC Powers On
    ↓
Windows Boots (1 minute delay)
    ↓
Task Scheduler triggers startserver.bat
    ↓
Auto-installer runs silently:
  ├── Nginx starts (background)
  ├── PM2 resurrects backend (saved state)
  ├── MySQL verified (Windows service)
  ├── Cloudflare Tunnel auto-starts (if configured)
  └── Watchdog verifies all ports
    ↓
Server LIVE - zero manual intervention
```

---

## Data Safety

- **MySQL persists** through shutdowns, restarts, power failures
- **PM2 saves process list** → auto-recovers on reboot
- **Nginx auto-restarts** via Task Scheduler
- **Cloudflare Tunnel auto-starts** if token exists
- **All data stored locally** → nothing lost

---

## Remote Access Setup (Cloudflare Tunnel)

### Step 1: Create Cloudflare Account
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Sign up for free account
3. Add your domain (or use existing)

### Step 2: Create Tunnel
1. Go to **Zero Trust** → **Networks** → **Tunnels**
2. Click **Create a Tunnel**
3. Choose **cloudflared** connector
4. Name it (e.g., `achme-server`)
5. Click **Save**

### Step 3: Get Token
1. Under "Choose your environment", click **Windows**
2. Copy the **Tunnel Token** (long string at end of command)

### Step 4: Configure on Server
1. Run `startserver.bat` → Option 3
2. Paste the token
3. Tunnel starts automatically

### Step 5: Point Your Domain
1. In Cloudflare dashboard, go to your tunnel
2. Add **Public Hostname**
3. Subdomain: `achme` (or whatever you want)
4. Domain: `yourdomain.com`
5. Service type: `HTTP`
6. Service URL: `localhost:80`
7. Save

Now anyone can access `https://achme.yourdomain.com` from anywhere!

---

## File Structure

```
simple-react-spark-main/
├── startserver.bat              ← MAIN: Click this
├── stop-servers.bat             ← Graceful shutdown
├── start-servers.bat            ← Legacy direct start
├── cloudflared-token.txt        ← Your tunnel token (create this)
├── SERVER_GUIDE.md              ← Full documentation
├── final.md                     ← Architecture guide
│
├── server-deployment/
│   ├── auto-installer.ps1       ← Main setup engine
│   ├── auto-start-scheduler.ps1 ← Task Scheduler setup
│   ├── setup-cloudflare.ps1     ← Cloudflare launcher
│   ├── startup-watchdog.ps1     ← Health check + recovery
│   ├── live-monitor.ps1         ← Real-time dashboard
│   ├── dns-server.js            ← Local DNS resolver
│   ├── generate-certs.ps1       ← SSL cert generator
│   ├── ecosystem.config.js      ← PM2 config (fork, 1 instance)
│   └── nginx.conf               ← Nginx config
│
├── Deployment/
│   ├── achme/
│   │   ├── frontend/            ← Built React files
│   │   ├── backend/             ← Deployed Node.js app
│   │   ├── ssl/                 ← SSL certificates
│   │   └── logs/                ← Server logs
│   └── nginx/                   ← Nginx installation
│
├── frontend/                    ← React source
└── backend/                     ← Node.js source
```

---

## Security Features

- **SSL/TLS** - All traffic encrypted via Nginx
- **Private CA** - Internal certificates for `achme.com`
- **Cloudflare Tunnel** - Outbound-only (no open router ports)
- **No Port Forwarding** - Router stays completely secure
- **PM2 Process Manager** - Auto-restarts crashed services
- **Watchdog Monitoring** - Continuous health checks + self-healing
- **LAN IP Auto-Detection** - Certificates update on IP change

---

## Optimized for 20+ Users

- **PM2 Fork Mode** - Single stable instance (~75MB RAM)
- **Nginx Caching** - Fast static file delivery
- **MySQL Connection Pool** - Handles concurrent queries
- **WebSocket Support** - Real-time chat/notifications work remotely
- **File Uploads** - Up to 50MB via Nginx
- **Gzip Compression** - Reduced bandwidth usage

---

## Troubleshooting

### Server won't start
1. Check logs: `Deployment\achme\logs\auto-installer.log`
2. Run as Administrator for full features
3. Verify MySQL: `services.msc` → look for MySQL

### Port conflicts
- **80/443**: Skype, IIS, or other web server running
- **5000**: Previous backend didn't close (run `stop-servers.bat`)
- **3306**: MySQL not installed or not running

### Can't access https://achme.com
1. Check hosts file: `C:\Windows\System32\drivers\etc\hosts`
   - Must contain: `127.0.0.1 achme.com`
2. Install SSL cert: `Deployment\achme\ssl\AchmeRootCA.crt`
   - Double-click → Install → Trusted Root Certification Authorities

### Remote access not working
1. Check tunnel status: Menu Option 5
2. Verify token in `cloudflared-token.txt`
3. Confirm domain points to tunnel in Cloudflare dashboard

---

## Commands Reference

```bash
# Start server
startserver.bat

# Stop server
stop-servers.bat

# Check PM2
pm2 list
pm2 logs achme-backend
pm2 restart achme-backend

# View logs
type Deployment\achme\logs\backend-error.log
type Deployment\achme\logs\nginx-error.log
```
