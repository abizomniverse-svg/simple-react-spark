# Achme Communication - Server Manual Guide

## Project Root
```
E:\OBSIDIAN\simple-react-spark
```

---

## Quick Start (One Command)
```
Double-click: START.bat
```
That's it. Everything auto-checks, auto-installs, auto-starts.

---

## Manual Commands (Step by Step)

### Step 1: Install Node.js (if not installed)
Download from: https://nodejs.org/ (LTS version)
Verify:
```cmd
node --version
npm --version
```

### Step 2: Install PM2 (Process Manager)
```cmd
npm install -g pm2
```
Verify:
```cmd
pm2 --version
```

### Step 3: Install Backend Dependencies
```cmd
cd E:\OBSIDIAN\simple-react-spark\backend
set PUPPETEER_SKIP_DOWNLOAD=true
npm install
```

### Step 4: Install Frontend Dependencies
```cmd
cd E:\OBSIDIAN\simple-react-spark\frontend
npm install
```

### Step 5: Start MySQL
MySQL runs as a Windows process. Check if running:
```cmd
tasklist /FI "IMAGENAME eq mysqld.exe"
```
If NOT running, start the service:
```cmd
net start MySQL80
```
Or if service name is different:
```cmd
net start MySQL
```
Verify MySQL is listening on port 3306:
```cmd
powershell -Command "Test-NetConnection 127.0.0.1 -Port 3306"
```

### Step 6: Start Backend (via PM2)
```cmd
cd E:\OBSIDIAN\simple-react-spark
pm2 start server-deployment\ecosystem.config.js --only achme-backend
pm2 save
```
Verify backend is running:
```cmd
pm2 list
```
Check backend logs:
```cmd
pm2 logs achme-backend
```
Test API health endpoint:
```cmd
curl http://localhost:5000/api/health
```

### Step 7: Start Frontend (Vite Dev Server)
```cmd
cd E:\OBSIDIAN\simple-react-spark\frontend
npm run dev
```
Frontend will be available at: `http://localhost:5173`

### Step 8: Start DNS Server (optional, for achme.com domain)
```cmd
cd E:\OBSIDIAN\simple-react-spark\server-deployment
node dns-server.js
```
DNS resolves `achme.com` to your PC's LAN IP on port 53 (requires Administrator).

---

## All Services Running - Verify Everything

### Check All Ports
```cmd
:: Check MySQL (3306)
powershell -Command "Test-NetConnection 127.0.0.1 -Port 3306"

:: Check Backend API (5000)
powershell -Command "Test-NetConnection 127.0.0.1 -Port 5000"

:: Check Frontend (5173)
powershell -Command "Test-NetConnection 127.0.0.1 -Port 5173"
```

### Test API Endpoints
```cmd
:: Health check
curl http://localhost:5000/api/health

:: Test auth endpoint
curl http://localhost:5000/api/auth/login -X POST -H "Content-Type: application/json" -d "{\"email\":\"Kk@achmecommunication.com\",\"password\":\"admin123\"}"

:: Test client list (requires auth token)
curl http://localhost:5000/api/client -H "Authorization: Bearer YOUR_TOKEN"
```

### Test Database Connection
```cmd
cd E:\OBSIDIAN\simple-react-spark\backend
node -e "const db = require('./config/database'); db.connect((err) => { if (err) console.log('FAIL:', err.message); else console.log('OK: MySQL connected'); process.exit(0); });"
```

### Check PM2 Process
```cmd
pm2 list
pm2 logs achme-backend
pm2 monit
```

### Restart Backend
```cmd
pm2 restart achme-backend
```

### Stop Backend
```cmd
pm2 stop achme-backend
pm2 delete achme-backend
```

---

## Service Ports Summary

| Service | Port | URL | How to Start |
|---------|------|-----|--------------|
| MySQL | 3306 | `127.0.0.1:3306` | `net start MySQL80` |
| Backend API | 5000 | `http://localhost:5000` | `pm2 start server-deployment\ecosystem.config.js` |
| Frontend | 5173 | `http://localhost:5173` | `cd frontend && npm run dev` |
| DNS Server | 53 | `achme.com` → LAN IP | `node server-deployment\dns-server.js` |

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
| GET | `/api/Fields` | Form fields |
| GET | `/api/contract` | Contracts |
| GET | `/api/amc` | AMC records |
| GET | `/api/reports` | Reports |
| GET | `/api/notifications` | Notifications |
| WebSocket | `/socket.io/` | Real-time chat & notifications |

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

## Log Files

| Service | Log Location |
|---------|-------------|
| Backend | `E:\OBSIDIAN\simple-react-spark\logs\backend-out.log` |
| Backend Errors | `E:\OBSIDIAN\simple-react-spark\logs\backend-error.log` |
| Frontend | `E:\OBSIDIAN\simple-react-spark\logs\frontend.log` |
| DNS Server | `E:\OBSIDIAN\simple-react-spark\logs\dns-server.log` |

View logs:
```cmd
:: Backend logs
pm2 logs achme-backend

:: Raw log files
type E:\OBSIDIAN\simple-react-spark\logs\backend-out.log
type E:\OBSIDIAN\simple-react-spark\logs\frontend.log
```

---

## File Structure

```
E:\OBSIDIAN\simple-react-spark\
├── START.bat                    ← ONE CLICK: Starts everything
├── final.md                     ← This file (manual commands)
│
├── backend/
│   ├── server.js                ← Main backend entry
│   ├── config/database.js       ← MySQL connection
│   ├── routes/                  ← All API routes
│   ├── sockets/                 ← WebSocket handlers
│   ├── backendutil/             ← Utility functions
│   ├── migrations/              ← Database migrations
│   └── package.json             ← Backend dependencies
│
├── frontend/
│   ├── src/
│   │   ├── App.jsx              ← Main React app
│   │   ├── pages/               ← All page components
│   │   ├── components/          ← Reusable components
│   │   ├── api/                 ← API client
│   │   └── auth/                ← Login/Register
│   └── package.json             ← Frontend dependencies
│
├── server-deployment/
│   ├── ecosystem.config.js      ← PM2 configuration
│   ├── dns-server.js            ← Local DNS server
│   └── nginx.conf               ← Nginx config (for later)
│
└── logs/                        ← All service logs
```

---

## Troubleshooting

### Backend won't start
```cmd
pm2 logs achme-backend
```
Common issues:
- MySQL not running → `net start MySQL80`
- Missing dependencies → `cd backend && npm install`
- Port 5000 in use → kill process on port 5000

### Frontend won't start
```cmd
cd E:\OBSIDIAN\simple-react-spark\frontend
npm install
npm run dev
```
Common issues:
- Port 5173 in use → kill process on port 5173
- Missing dependencies → `npm install`

### MySQL not running
```cmd
:: Check if running
tasklist /FI "IMAGENAME eq mysqld.exe"

:: Start service
net start MySQL80

:: If service doesn't exist, find MySQL in Services
:: Press Win+R, type "services.msc", find MySQL, click Start
```

### API returns errors
```cmd
:: Test health endpoint
curl http://localhost:5000/api/health

:: Check database connection
cd E:\OBSIDIAN\simple-react-spark\backend
node -e "const db = require('./config/database'); db.connect((err) => { console.log(err ? 'FAIL: ' + err.message : 'OK'); });"
```

### Port conflicts
```cmd
:: Find what's using a port
netstat -ano | findstr :5000
netstat -ano | findstr :5173
netstat -ano | findstr :3306

:: Kill process by PID
taskkill /F /PID <PID>
```
