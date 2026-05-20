# Achme Communication - Server Guide

## Quick Start

**Double-click `START.bat`** → Everything auto-installs, auto-configures, auto-starts.

The script will auto-request Administrator privileges.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    YOUR WINDOWS PC = SERVER                   │
│                                                              │
│  Employee Device (WiFi/Ethernet)                             │
│       ↓                                                      │
│  DNS: achme.com → Server LAN IP (dns-server.js, port 53)     │
│       ↓                                                      │
│  Browser → https://achme.com → Server LAN IP:443             │
│       ↓                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Nginx (port 443, SSL)                               │    │
│  │   /           → Vite Frontend (port 5173)           │    │
│  │   /api/*      → Backend API (port 5000)             │    │
│  │   /socket.io/* → WebSocket (port 5000)              │    │
│  │   /uploads/*   → File uploads (port 5000)           │    │
│  └──────────────────────┬──────────────────────────────┘    │
│                         ↓                                    │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ Backend (PM2)    │  │ MySQL (port 3306)│                 │
│  │ Port 5000        │  │ Database: achme  │                 │
│  │ Node.js + Express│  │                  │                 │
│  └──────────────────┘  └──────────────────┘                 │
│                                                              │
│  DNS Server (port 53)                                        │
│    achme.com → LAN IP                                        │
│    *.achme.com → LAN IP                                      │
│    Other domains → 8.8.8.8 (Google DNS)                      │
└──────────────────────────────────────────────────────────────┘
```

---

## Service Stack

| Component | Port | Role |
|-----------|------|------|
| **Nginx** | 80/443 | Reverse proxy, SSL termination, routes to Frontend + Backend |
| **Vite (Frontend)** | 5173 | React SPA development server |
| **Node.js + Express (Backend)** | 5000 | REST API + WebSocket (managed by PM2) |
| **MySQL** | 3306 | Database |
| **DNS Server** | 53 | Resolves achme.com → LAN IP for employee devices |
| **PM2** | - | Process manager, auto-restart on crash |

---

## Employee Access Setup (DNS Method)

### On Each Employee Device:

1. Open Network Settings
2. Set DNS Server to: **your server's LAN IP** (shown when START.bat runs)
3. Open browser → `https://achme.com`
4. Accept SSL certificate warning (first time only)
5. Done - full access to Achme CRM

### What Employees Can Access:

| Feature | URL | Works? |
|---------|-----|--------|
| Frontend | `https://achme.com` | Yes |
| Login | `https://achme.com/login` | Yes |
| API | `https://achme.com/api/*` | Yes |
| Real-time Chat | `https://achme.com` (WebSocket) | Yes |
| File Uploads | `https://achme.com/uploads/*` | Yes |
| Admin Panel | `https://achme.com/login` | Yes |

---

## Access URLs

### On Server PC (no DNS needed):

| URL | Description |
|-----|-------------|
| `https://achme.com` | Frontend (via Nginx) |
| `http://localhost:5173` | Frontend (direct Vite) |
| `http://localhost:5000/api/health` | Backend API health check |
| `https://localhost` | Frontend (via Nginx HTTPS) |
| `https://localhost/api/health` | Backend API (via Nginx HTTPS) |

### On LAN (other devices):

| URL | Description |
|-----|-------------|
| `https://achme.com` | Frontend (requires DNS set to server IP) |
| `https://<SERVER_IP>` | Frontend (direct IP, SSL warning) |
| `http://<SERVER_IP>:5173` | Frontend (direct Vite, no SSL) |
| `http://<SERVER_IP>:5000/api/health` | Backend API (direct) |

---

## Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | `Kk@achmecommunication.com` | `admin123` |

---

## Database

| Setting | Value |
|---------|-------|
| Host | `127.0.0.1` |
| Port | `3306` |
| User | `root` |
| Password | `admin@123` |
| Database | `achme` |

---

## Manual Commands

### Start Everything
```cmd
Double-click START.bat
```

### Start Individual Services

**Backend (PM2):**
```cmd
cd E:\OBSIDIAN\simple-react-spark
pm2 start server-deployment\ecosystem.config.js --only achme-backend
pm2 save
```

**Frontend (Vite):**
```cmd
cd E:\OBSIDIAN\simple-react-spark\frontend
npm run dev
```

**Nginx:**
```cmd
cd E:\OBSIDIAN\simple-react-spark\nginx
nginx.exe -c E:\OBSIDIAN\simple-react-spark\server-deployment\nginx.conf
```

**DNS Server:**
```cmd
node E:\OBSIDIAN\simple-react-spark\server-deployment\dns-server.js
```

**MySQL:**
```cmd
net start MySQL80
```

### Stop Individual Services

**Backend:**
```cmd
pm2 stop achme-backend
```

**Nginx:**
```cmd
cd E:\OBSIDIAN\simple-react-spark\nginx
nginx.exe -s quit
```

**Frontend:**
```cmd
taskkill /FI "WINDOWTITLE eq Achme Frontend*" /F
```

**DNS Server:**
```cmd
taskkill /F /IM node.exe
```

### Check Status

```cmd
pm2 list
pm2 logs achme-backend
pm2 monit

netstat -ano | findstr :5000
netstat -ano | findstr :5173
netstat -ano | findstr :443
netstat -ano | findstr :3306
```

### Test API

```cmd
curl http://localhost:5000/api/health
curl https://localhost/api/health -k
curl https://achme.com/api/health -k
```

### Test Database

```cmd
cd E:\OBSIDIAN\simple-react-spark\backend
node -e "const db = require('./config/database'); db.connect((err) => { console.log(err ? 'FAIL: ' + err.message : 'OK: MySQL connected'); });"
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/register` | Register |
| GET | `/api/client` | List clients |
| POST | `/api/client` | Create client |
| PUT | `/api/client/:id` | Update client |
| DELETE | `/api/client/:id` | Delete client |
| GET | `/api/invoice` | List invoices |
| POST | `/api/invoice` | Create invoice |
| GET | `/api/quotations` | List quotations |
| POST | `/api/quotations` | Create quotation |
| GET | `/api/Telecalls` | Telecalling records |
| GET | `/api/Walkins` | Walk-in records |
| GET | `/api/task` | Task list |
| POST | `/api/task` | Create task |
| GET | `/api/payments` | Payment records |
| POST | `/api/payments` | Create payment |
| GET | `/api/estimate` | Estimates |
| GET | `/api/contract` | Contracts |
| GET | `/api/amc` | AMC records |
| GET | `/api/reports` | Reports |
| GET | `/api/notifications` | Notifications |
| GET | `/api/Fields` | Form fields |
| GET | `/api/estimate-client` | Estimate clients |
| GET | `/api/service` | Service estimation |
| GET | `/api/unified-invoice` | Unified invoice |
| GET | `/api/performa` | Performa invoice |
| GET | `/api/targets` | Targets |
| GET | `/api/lead-management` | Lead management |
| GET | `/api/call-reports` | Call reports |
| WebSocket | `/socket.io/` | Real-time chat & notifications |

---

## Log Files

| Service | Log Location |
|---------|-------------|
| Backend Output | `logs\backend-out.log` |
| Backend Errors | `logs\backend-error.log` |
| Frontend | `logs\frontend.log` |
| DNS Server | `logs\dns-server.log` |
| Nginx Access | `logs\nginx-access.log` |
| Nginx Errors | `logs\nginx-error.log` |

View live logs:
```cmd
pm2 logs achme-backend
type logs\backend-out.log
type logs\nginx-error.log
```

---

## File Structure

```
E:\OBSIDIAN\simple-react-spark\
├── START.bat                          ← ONE CLICK: Starts everything
├── final.md                           ← This guide
│
├── backend/
│   ├── server.js                      ← Main backend entry
│   ├── config/database.js             ← MySQL connection
│   ├── routes/                        ← All API routes
│   ├── sockets/                       ← WebSocket handlers
│   ├── backendutil/                   ← Utility functions
│   ├── migrations/                    ← Database migrations
│   └── package.json                   ← Backend dependencies
│
├── frontend/
│   ├── src/
│   │   ├── App.jsx                    ← Main React app
│   │   ├── pages/                     ← All page components
│   │   ├── components/                ← Reusable components
│   │   ├── api/                       ← API client
│   │   └── auth/                      ← Login/Register
│   └── package.json                   ← Frontend dependencies
│
├── server-deployment/
│   ├── ecosystem.config.js            ← PM2 configuration
│   ├── dns-server.js                  ← Local DNS server
│   ├── nginx.conf                     ← Nginx reverse proxy config
│   ├── install-nginx.ps1              ← Auto-download Nginx
│   ├── setup-hosts.ps1                ← Configure hosts file
│   ├── setup-firewall.ps1             ← Open firewall ports
│   └── generate-certs.ps1             ← Generate SSL certificates
│
├── nginx/                             ← Nginx installation (auto-created)
│   └── nginx.exe
│
├── ssl/                               ← SSL certificates (auto-created)
│   ├── achme.crt                      ← Domain certificate
│   ├── achme.key                      ← Private key
│   └── AchmeRootCA.crt                ← Root CA certificate
│
└── logs/                              ← All service logs (auto-created)
```

---

## Troubleshooting

### Server won't start
1. Run `START.bat` as Administrator
2. Check logs: `logs\backend-error.log`, `logs\nginx-error.log`
3. Verify MySQL: `services.msc` → find MySQL → Start

### Port conflicts
```cmd
:: Find what's using a port
netstat -ano | findstr :5000
netstat -ano | findstr :5173
netstat -ano | findstr :443

:: Kill process by PID
taskkill /F /PID <PID>
```

### Nginx won't start
1. Check logs: `logs\nginx-error.log`
2. Verify SSL certs exist: `ssl\achme.crt` and `ssl\achme.key`
3. Test config: `cd nginx && nginx.exe -t -c ..\server-deployment\nginx.conf`
4. Reload: `cd nginx && nginx.exe -s reload`

### SSL certificate warning on employee devices
- This is normal for self-signed certificates
- Click "Advanced" → "Proceed to achme.com (unsafe)"
- Only happens once per device/browser

### Can't access from LAN
1. Verify firewall: `START.bat` opens ports automatically
2. Check Windows Firewall settings
3. Verify employee device DNS is set to server IP
4. Test direct IP: `https://<SERVER_IP>`

### Backend API not responding
```cmd
pm2 logs achme-backend
pm2 restart achme-backend
pm2 list
```

### MySQL not connecting
```cmd
net start MySQL80
tasklist /FI "IMAGENAME eq mysqld.exe"
```

### DNS not resolving achme.com
```cmd
:: On server PC
ipconfig /flushdns
ping achme.com

:: On employee device
nslookup achme.com <SERVER_IP>
```

---

## How START.bat Works

1. **Admin Check** - Auto-restarts as Administrator if not already
2. **LAN IP Detection** - Finds your PC's active LAN IP
3. **Node.js Check** - Verifies Node.js is installed
4. **PM2 Install** - Auto-installs PM2 if missing
5. **Nginx Install** - Auto-downloads Nginx for Windows if missing
6. **Backend Deps** - Installs `npm` packages for backend
7. **Frontend Deps** - Installs `npm` packages for frontend
8. **MySQL Check** - Verifies/starts MySQL service
9. **Hosts File** - Adds `127.0.0.1 achme.com` to hosts file
10. **Firewall** - Opens ports 80, 443, 53, 5000, 5173
11. **SSL Certs** - Generates self-signed certificates for achme.com
12. **CORS Update** - Updates backend CORS with detected LAN IP
13. **Kill Stale** - Stops any existing processes on used ports
14. **Start Backend** - Launches via PM2 on port 5000
15. **Start DNS** - Launches DNS server on port 53
16. **Start Nginx** - Launches reverse proxy on ports 80/443
17. **Start Frontend** - Launches Vite dev server on port 5173
18. **Verify** - Tests all connections (API, MySQL, Nginx, DNS)
19. **Dashboard** - Shows status, URLs, credentials, commands
20. **Live Logs** - Streams all log files in real-time

---

## Security Notes

- **Self-signed SSL** - Employees see a warning once, then it's trusted per session
- **No port forwarding** - Router stays secure, all traffic stays on LAN
- **Firewall rules** - Only required ports are opened
- **Private CA** - Root CA is installed locally for certificate trust
- **PM2 auto-restart** - Backend recovers automatically from crashes
