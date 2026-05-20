# Achme Enterprise Private Cloud Server

Your Windows PC transformed into a professional-grade private company server.

## Quick Start

1. **Double-click `startserver.bat`** - Opens the control panel
2. **Press `1`** - Starts all services (Nginx + Backend + Monitors)
3. **Open browser** → `https://achme.com`

That's it. Your server is live.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR WINDOWS PC                          │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  Nginx   │───▶│   PM2    │───▶│  MySQL   │              │
│  │ Port 80  │    │ Port 5000│    │ Port 3306│              │
│  │ Port 443 │    │(Node.js) │    │          │              │
│  └────┬─────┘    └──────────┘    └──────────┘              │
│       │                                                   │
│       ▼                                                   │
│  ┌──────────────────┐    ┌──────────────────┐             │
│  │  React Frontend  │    │ Cloudflare Tunnel│             │
│  │  (Static Files)  │    │  (Remote Access) │             │
│  └──────────────────┘    └────────┬─────────┘             │
│                                   │                       │
└───────────────────────────────────┼───────────────────────┘
                                    │
                           ┌────────▼─────────┐
                           │  Internet Users  │
                           │  https://domain  │
                           └──────────────────┘
```

### Components

| Service | Port | Purpose |
|---------|------|---------|
| **Nginx** | 80/443 | Reverse proxy, SSL termination, static file serving |
| **Node.js Backend** | 5000 | Express API (managed by PM2) |
| **MySQL** | 3306 | Database (persists across reboots) |
| **Cloudflare Tunnel** | Outbound only | Secure remote access (no port forwarding) |

---

## Control Panel Options

When you run `startserver.bat`:

```
[1] START SERVER     - Launch all services + monitoring tabs
[2] STOP SERVER      - Gracefully shutdown everything
[3] SETUP CLOUDFLARE - Enable worldwide remote access
[4] SETUP AUTO-START - Auto-launch on Windows boot
[5] VIEW STATUS      - Check all services health
[6] VIEW LOGS        - Open log files
[0] EXIT
```

---

## Access Your Server

### Local Network (Office)
- Open browser: `https://achme.com`
- Works on any device connected to same Wi-Fi/LAN

### Remote Access (Anywhere in World)

**Option A: Cloudflare Tunnel (Recommended)**
1. Run `startserver.bat` → Option 3
2. Create free Cloudflare account
3. Go to Zero Trust → Networks → Tunnels
4. Create tunnel → Copy the TOKEN
5. Paste token when prompted
6. Point your domain to `http://localhost:80` in Cloudflare dashboard
7. Done! Access from anywhere via your domain

**Option B: Tailscale VPN**
1. Install Tailscale on server and client devices
2. Join same Tailscale network
3. Access via `https://achme.com` from any device

---

## Auto-Start on Boot

Your server automatically starts when Windows boots:

1. **Windows Task Scheduler** - Primary method (runs as system)
2. **Startup Folder Shortcut** - Fallback method (runs on login)

To configure: Run `startserver.bat` → Option 4

### What Happens on Boot

```
Windows Boots
    ↓
1 minute delay (let system initialize)
    ↓
startserver.bat launches silently
    ↓
Auto-installer runs:
  ├── Nginx starts (background)
  ├── PM2 resurrects backend
  ├── MySQL verified (already running as service)
  └── Cloudflare Tunnel starts (if configured)
    ↓
Server is LIVE - no manual action needed
```

---

## Data Safety

- **MySQL data persists** through shutdowns, restarts, power failures
- **PM2 saves process list** - auto-recovers backend on reboot
- **Nginx auto-restarts** via Task Scheduler
- **All files stored locally** - nothing is lost

---

## File Structure

```
simple-react-spark-main/
├── startserver.bat          ← MAIN: Click this to start
├── stop-servers.bat         ← Graceful shutdown
├── start-servers.bat        ← Legacy direct start
├── cloudflared-token.txt    ← Your tunnel token (create this)
│
├── server-deployment/
│   ├── auto-installer.ps1   ← Main setup engine
│   ├── auto-start-scheduler.ps1 ← Windows Task Scheduler setup
│   ├── setup-cloudflare.ps1 ← Cloudflare Tunnel launcher
│   ├── startup-watchdog.ps1 ← Health check + auto-recovery
│   ├── live-monitor.ps1     ← Real-time status dashboard
│   ├── dns-server.js        ← Local DNS resolver
│   ├── generate-certs.ps1   ← SSL certificate generator
│   ├── ecosystem.config.js  ← PM2 configuration
│   └── nginx.conf           ← Nginx configuration
│
├── Deployment/
│   ├── achme/
│   │   ├── frontend/        ← Built React files
│   │   ├── backend/         ← Deployed Node.js app
│   │   ├── ssl/             ← SSL certificates
│   │   └── logs/            ← Server logs
│   └── nginx/               ← Nginx installation
│
├── frontend/                ← React source code
└── backend/                 ← Node.js source code
```

---

## Troubleshooting

### Server won't start
1. Check logs: `Deployment\achme\logs\auto-installer.log`
2. Run as Administrator
3. Verify MySQL is running: `services.msc` → MySQL

### Port already in use
- Port 80/443: Another web server running (Skype, IIS, etc.)
- Port 5000: Previous backend didn't close (run stop-servers.bat)
- Port 3306: MySQL not installed or not running

### Can't access https://achme.com
1. Check hosts file: `C:\Windows\System32\drivers\etc\hosts`
   - Should contain: `127.0.0.1 achme.com`
2. Install SSL certificate: `Deployment\achme\ssl\AchmeRootCA.crt`
   - Double-click → Install → Trusted Root Certification Authorities

### Remote access not working
1. Verify Cloudflare Tunnel is running (Option 5 in menu)
2. Check token in `cloudflared-token.txt`
3. Verify domain points to tunnel in Cloudflare dashboard

---

## Security

- **SSL/TLS** - All traffic encrypted via Nginx
- **Private CA** - Internal certificates for local domain
- **Cloudflare Tunnel** - Outbound-only connection (no open ports)
- **No Port Forwarding** - Router stays secure
- **PM2 Process Manager** - Auto-restarts crashed services
- **Watchdog Monitoring** - Continuous health checks

---

## For 20+ Users

The system is optimized for your team:
- **PM2 Fork Mode** - Single stable instance (~75MB RAM)
- **Nginx Caching** - Fast static file delivery
- **MySQL Connection Pool** - Handles concurrent queries
- **WebSocket Support** - Real-time features work remotely
- **File Uploads** - Up to 50MB via Nginx

---

## Commands Reference

```bash
# Start server
startserver.bat

# Stop server
stop-servers.bat

# Check PM2 status
pm2 list
pm2 logs achme-backend

# Restart backend only
pm2 restart achme-backend

# View logs
type Deployment\achme\logs\backend-error.log
type Deployment\achme\logs\nginx-error.log
```

---

## Support

- Logs: `Deployment\achme\logs\`
- SSL Certs: `Deployment\achme\ssl\`
- PM2 Logs: `~/.pm2/logs/`
