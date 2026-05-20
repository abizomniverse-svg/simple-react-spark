# Achme Enterprise CRM: Windows Server Deployment Runbook
**Target Environment:** Private Self-Hosted Windows Server Environment
**Primary Domain:** `https://achme.com` (Frontend) | `https://api.achme.com` (Backend API)
**Security Level:** Enterprise Private (Closed Internal Network + Tailscale Zero-Trust VPN)

This comprehensive runbook contains step-by-step instructions to deploy, secure, and automate the Achme CRM system. Follow this guide systematically to achieve a professional, automated, and reboot-resilient deployment.

---

## Table of Contents
1. [System Architecture Overview](#1-system-architecture-overview)
2. [Prerequisites & Software Installation](#2-prerequisites--software-installation)
3. [Phase 1: Initialize Deployment Folders](#phase-1-initialize-deployment-folders)
4. [Phase 2: Build & Copy Application Files](#phase-2-build--copy-application-files)
5. [Phase 3: Generate Local Enterprise CA & SSL Certificates](#phase-3-generate-local-enterprise-ca--ssl-certificates)
6. [Phase 4: Install and Configure Nginx Service](#phase-4-install-and-configure-nginx-service)
7. [Phase 5: Install and Configure PM2 Backend Service](#phase-5-install-and-configure-pm2-backend-service)
8. [Phase 6: MySQL Hardening & Crash-Resiliency](#phase-6-mysql-hardening--crash-resiliency)
9. [Phase 7: Secure Inbound Firewall Rules](#phase-7-secure-inbound-firewall-rules)
10. [Phase 8: Private Network DNS Configuration (Local & Remote)](#phase-8-private-network-dns-configuration-local--remote)
11. [Phase 9: Automated Daily Database Backups](#phase-9-automated-daily-database-backups)
12. [Phase 10: Automatic Reboot Watchdog Setup](#phase-10-automatic-reboot-watchdog-setup)
13. [Operations: Recovery, Backups & Rollbacks](#operations-recovery-backups--rollbacks)

---

## 1. System Architecture Overview

```
                        [ In-Office Employees ]            [ Remote Employees ]
                               │                                    │
                         (Local Wi-Fi)                      (Tailscale Secure VPN)
                               │                                    │
                               ▼                                    ▼
                     [ Local Router DNS ]                 [ Tailscale DNS Rule ]
                 (achme.com -> 192.168.1.100)        (achme.com -> 100.X.Y.Z)
                               │                                    │
                               └─────────────────┬──────────────────┘
                                                 │
                                                 ▼
                                     [ Windows Server Host ]
                                     ┌───────────────────────────────────┐
                                     │ Windows Defender Firewall         │
                                     │ (Allows ports 80/443 ONLY)        │
                                     └─────────────────┬─────────────────┘
                                                       │
                                                       ▼
                                           [ Nginx Reverse Proxy ]
                                           (Port 80/443 SSL Service)
                                           ┌───────────┴───────────┐
                                           │                       │
                                    (Static Files)           (API Proxy)
                                           ▼                       ▼
                                   [ Built React App ]      [ PM2 Node Cluster ]
                                  (C:/Deployment/achme)    (127.0.0.1:5000 Cluster)
                                                                   │
                                                                   ▼
                                                            [ MySQL Server ]
                                                        (127.0.0.1:3306 Secured)
```

---

## 2. Prerequisites & Software Installation

Ensure the following tools are installed on the host Windows Server before starting:

1.  **Node.js (LTS version):** Install via the official installer (https://nodejs.org/).
2.  **MySQL Server 8.0+:** Install via MySQL Installer, selecting server-only or full installation.
3.  **Nginx for Windows:** Download the latest stable zip (http://nginx.org/), extract to `C:\nginx`.
4.  **NSSM (Non-Sucking Service Manager):** Download from http://nssm.cc/ and extract `win64\nssm.exe` to `C:\Windows\System32\` (adds `nssm` command-line capability globally).
5.  **Git for Windows:** Download and install (https://git-scm.com/). This provides `openssl.exe` which is used for certificate key extraction.
6.  **Tailscale:** Download and install the Windows agent (https://tailscale.com/).

---

## Phase 1: Initialize Deployment Folders

1.  Open **PowerShell** as **Administrator**.
2.  Navigate to your workspace's deployment script folder:
    ```powershell
    cd E:\simple-react-spark-main\server-deployment
    ```
3.  Execute the initialization script:
    ```powershell
    .\setup.ps1
    ```
    This script initializes the directory structure under `C:\Deployment\achme\` with the folders: `frontend`, `backend`, `ssl`, `logs`, and `backups`.

---

## Phase 2: Build & Copy Application Files

### 1. Build and Deploy React Frontend
To ensure high performance and low resource consumption, we compile the React frontend into static assets and let Nginx serve them directly:
1.  Open a terminal and navigate to the frontend directory:
    ```cmd
    cd E:\simple-react-spark-main\frontend
    ```
2.  Build the production bundle:
    ```cmd
    npm run build
    ```
3.  Copy all contents of `E:\simple-react-spark-main\frontend\build\` (or `dist\`) to:
    `C:\Deployment\achme\frontend\`

### 2. Deploy Node.js Backend
1.  Copy all files inside `E:\simple-react-spark-main\backend\` (excluding the heavy `node_modules` folder) to:
    `C:\Deployment\achme\backend\`
2.  Open command prompt as Administrator and install dependencies in production mode:
    ```cmd
    cd C:\Deployment\achme\backend
    npm install --production
    ```

---

## Phase 3: Generate Local Enterprise CA & SSL Certificates

To secure all communications with a padlock and eliminate browser warnings:
1.  Open **PowerShell** as **Administrator**.
2.  Run the certificate generation script:
    ```powershell
    cd E:\simple-react-spark-main\server-deployment
    .\generate-certs.ps1
    ```
    **What this script does:**
    *   Generates a dedicated high-strength **Achme Private Root CA** certificate.
    *   Installs this Root CA into the server's **Local Machine Trusted Root Certification Authorities store**, so the server itself trusts the certificates.
    *   Generates a wildcard certificate (`*.achme.com` and `achme.com`) signed by this CA.
    *   Automatically locates Git's OpenSSL to extract the private key, saving Nginx-ready files at:
        *   Certificate: `C:\Deployment\achme\ssl\achme.crt`
        *   Private Key: `C:\Deployment\achme\ssl\achme.key`
        *   Public Root CA: `C:\Deployment\achme\ssl\AchmeRootCA.crt`

### ⚠️ IMPORTANT: Installing the Certificate on Employee Devices
To bypass SSL warnings on client machines, you must install the generated `AchmeRootCA.crt` **once** on each client device:
*   **Windows:** Double-click `AchmeRootCA.crt` -> Click **Install Certificate** -> Choose **Local Machine** -> Choose **Place all certificates in the following store** -> Browse and select **Trusted Root Certification Authorities** -> Complete wizard.
*   **macOS:** Double-click the file to add to Keychain Access -> Open **Keychain Access** -> Find **Achme Private Root CA** under "System" -> Double-click -> Expand **Trust** -> Change "When using this certificate" to **Always Trust**.
*   **iOS / Android:** Email or host the `AchmeRootCA.crt` file -> Open it on the mobile device -> Install profile -> On iOS: Go to Settings -> General -> About -> Certificate Trust Settings -> Enable full trust for root certificates.

---

## Phase 4: Install and Configure Nginx Service

1.  Copy the provided `nginx.conf` to the Nginx installation directory, replacing the default one:
    ```cmd
    copy "E:\simple-react-spark-main\server-deployment\nginx.conf" "C:\nginx\conf\nginx.conf" /Y
    ```
2.  Validate the Nginx configuration syntax:
    ```cmd
    cd C:\nginx
    nginx.exe -t
    ```
    *(Ensure it returns syntax is ok and test is successful)*
3.  Install Nginx as a native Windows Service using NSSM:
    ```cmd
    nssm install Nginx "C:\nginx\nginx.exe"
    nssm set Nginx AppDirectory "C:\nginx"
    nssm set Nginx DisplayName "Achme Nginx Proxy"
    nssm set Nginx Description "Reverse proxy for Achme frontend and api.achme.com"
    nssm set Nginx Start SERVICE_AUTO_START
    ```
4.  Start the service:
    ```cmd
    net start Nginx
    ```

---

## Phase 5: Install and Configure PM2 Backend Service

1.  Install PM2 and the PM2 Windows service packages globally:
    ```cmd
    npm install -g pm2 pm2-windows-startup
    ```
2.  Install the PM2 startup script configuration:
    ```cmd
    pm2-startup install
    ```
3.  Copy our production PM2 configuration file:
    ```cmd
    copy "E:\simple-react-spark-main\server-deployment\ecosystem.config.js" "C:\Deployment\achme\ecosystem.config.js" /Y
    ```
4.  Start the backend cluster using the ecosystem configuration:
    ```cmd
    cd C:\Deployment\achme
    pm2 start ecosystem.config.js
    ```
5.  **CRITICAL:** Save the running PM2 processes so they are restored automatically on boot:
    ```cmd
    pm2 save
    ```

---

## 6. MySQL Hardening & Crash-Resiliency

Since the Windows Server turns off manually every night, we must configure MySQL to write data immediately to disk to prevent data corruption.
1.  Open the MySQL configuration file (usually located at `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini`).
2.  Verify the database is secure and bound **only** to the local machine:
    ```ini
    [mysqld]
    bind-address = 127.0.0.1
    mysqlx-bind-address = 127.0.0.1
    ```
3.  Add or modify the following crash-resilient InnoDB settings under the `[mysqld]` section:
    ```ini
    # Force flushing of transactions on commit immediately
    innodb_flush_log_at_trx_commit = 1
    
    # Synchronize binary logs on commit
    sync_binlog = 1
    
    # Use native Windows AIO for fast async disk writes
    innodb_use_native_aio = 1
    ```
4.  Open PowerShell as Administrator and restart the MySQL service:
    ```powershell
    Restart-Service -Name "MySQL80" -Force
    ```

---

## 7. Secure Inbound Firewall Rules

To protect the server, we close all developer/database ports to the LAN and only permit ports `80` (HTTP) and `443` (HTTPS):
1.  Open **PowerShell** as **Administrator**.
2.  Run the following commands to configure Windows Defender Firewall:
    ```powershell
    # Allow Nginx HTTP Port 80 for LAN and VPN
    New-NetFirewallRule -DisplayName "Achme Nginx HTTP (Port 80)" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow -Profile Domain, Private

    # Allow Nginx HTTPS Port 443 for LAN and VPN
    New-NetFirewallRule -DisplayName "Achme Nginx HTTPS (Port 443)" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow -Profile Domain, Private

    # Ensure Developer Backend Port 5000 is BLOCKED Inbound
    New-NetFirewallRule -DisplayName "Block Inbound Node Backend Port 5000" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Block

    # Ensure Database Port 3306 is BLOCKED Inbound from network
    New-NetFirewallRule -DisplayName "Block Inbound MySQL Port 3306" -Direction Inbound -LocalPort 3306 -Protocol TCP -Action Block
    ```

---

## 8. Private Network DNS Configuration (Local & Remote)

To resolve `achme.com` and `api.achme.com` properly:

### 1. For Devices Connected to In-Office Wi-Fi (Choose One)
*   **Method A: Local Router/Pi-hole (Recommended)**
    *   Access your office router or Pi-hole admin panel.
    *   Add a local static DNS entry / DNS lease rule mapping:
        *   `achme.com` -> `[Server Static LAN IP, e.g., 192.168.1.100]`
        *   `api.achme.com` -> `[Server Static LAN IP, e.g., 192.168.1.100]`
*   **Method B: Windows DNS Server**
    *   Open DNS Manager. Create a Forward Lookup Zone for `achme.com`.
    *   Add an **A Record** with blank name pointing to `192.168.1.100`.
    *   Add an **A Record** named `api` pointing to `192.168.1.100`.
*   **Method C: Local Workstation Host File Automation**
    *   Execute this command on an employee's Windows machine running PowerShell as Administrator:
        ```powershell
        Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "`r`n192.168.1.100 achme.com`r`n192.168.1.100 api.achme.com"
        ```

### 2. For Secure Remote Access (Outside the Office)
1.  Install **Tailscale** on the Windows Server and log in to your company Tailscale network (Tailnet).
2.  Enable Tailscale as a Windows service (default) so it starts automatically on boot.
3.  Note the private Tailscale IP of your server (e.g., `100.80.90.100`).
4.  Log in to your **Tailscale Admin Console** (https://login.tailscale.com/).
5.  Go to **DNS** -> **Nameservers** -> **Add Nameserver** -> **Restrict to domain** (Split DNS).
6.  Set **Domain** to `achme.com` and **IP Address** to your Windows Server's private Tailscale IP (`100.80.90.100`).
7.  Now, when employees are outside the office and turn on their Tailscale VPN, `https://achme.com` will securely route directly to the server's private VPN IP!

---

## 9. Automated Daily Database Backups

Ensure backups are archived daily using our robust, space-saving backup script:
1.  Open **Windows Task Scheduler** (`taskschd.msc`).
2.  Click **Create Basic Task...** in the right Actions panel.
3.  Name the task: `MySQL Daily Backup`.
4.  **Trigger:** Daily. Set the start time to `8:00 PM` or another time prior to server shutdown.
5.  **Action:** `Start a program`.
6.  Set **Program/script** to: `powershell.exe`
7.  Set **Add arguments** to:
    ```
    -ExecutionPolicy Bypass -File "E:\simple-react-spark-main\server-deployment\backup.ps1"
    ```
8.  Click Finish. Under **Properties** of the task, check **Run whether user is logged on or not** and **Run with highest privileges** (uses Admin permissions).
9.  Right-click the task and select **Run** to test. Confirm that a compressed ZIP file is created inside `C:\Deployment\achme\backups\` and audit logs write to `C:\Deployment\achme\logs\backup.log`.

---

## 10. Automatic Reboot Watchdog Setup

Since the server boots up manually every morning, we want a watchdog task to verify and start all services without administrator manual interaction:
1.  Open **Windows Task Scheduler** (`taskschd.msc`).
2.  Click **Create Task...**
3.  **General Tab:**
    *   Name: `Achme Startup Watchdog`
    *   Security options: Select **Run whether user is logged on or not**.
    *   Select **Run with highest privileges**.
    *   Configure for: `Windows 10` or `Windows Server 2016` (or appropriate version).
4.  **Triggers Tab:**
    *   Click **New...** -> Select **At startup**.
5.  **Actions Tab:**
    *   Click **New...** -> Select **Start a program**.
    *   Set **Program/script** to: `powershell.exe`
    *   Set **Add arguments** to:
        ```
        -ExecutionPolicy Bypass -File "E:\simple-react-spark-main\server-deployment\startup-watchdog.ps1"
        ```
6.  **Conditions Tab:** Uncheck "Start the task only if the computer is on AC power".
7.  Click OK and enter your server administrative password.
8.  Simulate a reboot. Observe `C:\Deployment\achme\logs\startup.log` to verify that ports `3306, 5000, 80, 443` all start successfully and automatically on boot!

---

## Operations: Recovery, Backups & Rollbacks

### 1. Restoring a Database Backup
If database corruption occurs or data needs to be rolled back to a previous day:
1.  Open PowerShell as Administrator.
2.  Locate your latest backup zip file inside `C:\Deployment\achme\backups\`.
3.  Extract the ZIP file to retrieve the SQL file (e.g. `achme_backup_YYYY-MM-DD.sql`).
4.  Import the SQL dump into MySQL:
    ```powershell
    mysql -u root -padmin@123 achme < C:\Deployment\achme\backups\achme_backup_YYYY-MM-DD.sql
    ```

### 2. Manual System Start/Stop
Should you ever need to manually restart all systems:
*   **Nginx Server:** `net stop Nginx` / `net start Nginx`
*   **PM2 Backend:** `pm2 stop achme-backend` / `pm2 start achme-backend`
*   **MySQL Server:** `Stop-Service -Name MySQL80` / `Start-Service -Name MySQL80`
*   **Tailscale Service:** `Stop-Service -Name Tailscale` / `Start-Service -Name Tailscale`

### 3. Application Code Updates (Fix-Forward / Deployment)
When developers update the frontend or backend application code:
1.  Build the new React bundle and copy it to `C:\Deployment\achme\frontend\` (overwriting existing static files). This updates the UI instantly with **zero downtime**.
2.  Copy new backend files to `C:\Deployment\achme\backend\`.
3.  Perform a graceful cluster reload of the Node server to apply changes with **zero downtime**:
    ```cmd
    pm2 reload achme-backend
    ```
4.  Verify backend output in `C:\Deployment\achme\logs\backend-out.log` to confirm the update is running clean.
