# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
}
$SslDir = Join-Path $DeploymentRoot "ssl"
$CaSubject = "CN=Achme Private Root CA, O=Achme Corporation, C=US"
$CertSubject = "CN=achme.com"

# Discover the active local LAN IPv4 address dynamically at runtime
$ActiveLanIp = "127.0.0.1"
try {
    $ActiveLanIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi', 'Ethernet' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    if (-not $ActiveLanIp) {
        $ActiveLanIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    }
} catch {}

if (-not $ActiveLanIp) {
    $ActiveLanIp = "127.0.0.1"
}

$DnsNames = @("achme.com", "*.achme.com", "localhost", "127.0.0.1")
if ($ActiveLanIp -ne "127.0.0.1") {
    $DnsNames += $ActiveLanIp
    Write-Output "[INFO] Dynamic IP SAN Injection: Added $ActiveLanIp to certificate alternative names."
}

$PfxPassword = "AchmeSecurePass123!"

try {
    Write-Output "[INFO] Starting SSL certificate generation process..."

    # Detect user privilege level
    if ($IsAdmin) {
        $StoreLocation = "LocalMachine"
        Write-Output "[INFO] Running as ADMINISTRATOR. Certificates will be registered in Local Machine store."
    } else {
        $StoreLocation = "CurrentUser"
        Write-Output "[INFO] Running as STANDARD USER. Certificates will be registered in Current User store."
    }

    $StorePath = "Cert:\$StoreLocation\My"

    # Ensure SSL directory exists
    if (-not (Test-Path -LiteralPath $SslDir)) {
        New-Item -ItemType Directory -Path $SslDir -Force | Out-Null
    }

    # 1. Generate/Locate Private Root CA
    Write-Output "[INFO] Checking for existing Achme Root CA in $StoreLocation Personal Store..."
    $CaCert = Get-ChildItem -Path $StorePath | Where-Object { $_.Subject -eq $CaSubject } | Select-Object -First 1

    if ($CaCert) {
        Write-Output "[INFO] Found existing Achme Root CA in store."
    } else {
        Write-Output "[INFO] Generating new Achme Private Root CA..."
        # Create a self-signed Root CA certificate
        $CaCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
            -Subject $CaSubject -KeyExportPolicy Exportable `
            -HashAlgorithm sha256 -KeyLength 2048 `
            -CertStoreLocation $StorePath `
            -KeyUsage CertSign, CRLSign, DigitalSignature `
            -NotAfter (Get-Date).AddYears(10)
        Write-Output "[OK] Generated new Achme Private Root CA."
    }

    # 2. Install Root CA into Trusted Root Certification Authorities
    Write-Output "[INFO] Installing Achme Root CA into Trusted Root Store ($StoreLocation)..."
    $RootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", $StoreLocation)
    $RootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    
    # Check if already installed in Root store
    $IsInstalled = $false
    foreach ($Cert in $RootStore.Certificates) {
        if ($Cert.Thumbprint -eq $CaCert.Thumbprint) {
            $IsInstalled = $true
            break
        }
    }

    if (-not $IsInstalled) {
        $RootStore.Add($CaCert)
        Write-Output "[OK] Achme Root CA successfully installed in Trusted Root Store."
    } else {
        Write-Output "[INFO] Achme Root CA is already installed in Trusted Root Store."
    }
    $RootStore.Close()

    # Export CA Certificate to PEM format for client installations
    $CaCertPath = Join-Path -Path $SslDir -ChildPath "AchmeRootCA.crt"
    $CaCertPem = "-----BEGIN CERTIFICATE-----`r`n" + [System.Convert]::ToBase64String($CaCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`r`n-----END CERTIFICATE-----"
    $CaCertPem | Out-File -FilePath $CaCertPath -Encoding ascii -Force
    Write-Output "[OK] Exported Public CA Root Certificate to: $CaCertPath"

    # 3. Generate Wildcard Domain Certificate signed by our CA
    Write-Output "[INFO] Generating wildcard certificate for achme.com signed by Achme Root CA..."
    
    # Generate the SSL Server Authentication certificate
    $DomainCert = New-SelfSignedCertificate -Type SSLServerAuthentication `
        -Subject $CertSubject -DnsName $DnsNames `
        -Signer $CaCert -KeyExportPolicy Exportable `
        -HashAlgorithm sha256 -KeyLength 2048 `
        -CertStoreLocation $StorePath `
        -NotAfter (Get-Date).AddYears(3)

    Write-Output "[OK] Wildcard certificate created in Personal Store."

    # 4. Export wildcard certificate as Nginx-compatible PEM files
    Write-Output "[INFO] Exporting wildcard certificate to PEM files..."
    
    # Export public certificate
    $CertPath = Join-Path -Path $SslDir -ChildPath "achme.crt"
    $CertPem = "-----BEGIN CERTIFICATE-----`r`n" + [System.Convert]::ToBase64String($DomainCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`r`n-----END CERTIFICATE-----"
    $CertPem | Out-File -FilePath $CertPath -Encoding ascii -Force
    Write-Output "[OK] Exported Public SSL Certificate to: $CertPath"

    # Export private key by first writing a PFX and then using openssl to extract the key
    $PfxPath = Join-Path -Path $SslDir -ChildPath "achme.pfx"
    $SecurePassword = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
    Export-PfxCertificate -Cert $DomainCert -FilePath $PfxPath -Password $SecurePassword -Force | Out-Null
    Write-Output "[INFO] Generated temporary PFX file at: $PfxPath"

    # Find openssl.exe
    $OpenSslPath = ""
    $SearchPaths = @(
        "openssl.exe", # In PATH
        "C:\Program Files\Git\usr\bin\openssl.exe",
        "C:\Program Files (x86)\Git\usr\bin\openssl.exe",
        "C:\Program Files\Git\bin\openssl.exe",
        (Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Programs\Git\usr\bin\openssl.exe")
    )

    foreach ($Path in $SearchPaths) {
        if ($Path -eq "openssl.exe") {
            $Check = Get-Command "openssl.exe" -ErrorAction SilentlyContinue
            if ($Check) {
                $OpenSslPath = "openssl.exe"
                break
            }
        } elseif (Test-Path -LiteralPath $Path) {
            $OpenSslPath = $Path
            break
        }
    }

    $KeyPath = Join-Path -Path $SslDir -ChildPath "achme.key"

    if ($OpenSslPath -ne "") {
        Write-Output "[INFO] Found OpenSSL at: $OpenSslPath"
        Write-Output "[INFO] Extracting private key using OpenSSL..."
        
        # Execute OpenSSL command to extract private key without password prompt
        $Command = "& `"$OpenSslPath`" pkcs12 -in `"$PfxPath`" -nocerts -nodes -out `"$KeyPath`" -password pass:`"$PfxPassword`""
        Invoke-Expression $Command | Out-Null
        
        if (Test-Path -LiteralPath $KeyPath) {
            Write-Output "[OK] Successfully extracted private key to: $KeyPath"
            
            # Clean up PFX for security
            Remove-Item -Path $PfxPath -Force
            Write-Output "[INFO] Removed temporary PFX file."
        } else {
            Write-Warning "[WARN] OpenSSL extraction did not produce a key file. Keeping PFX."
        }
    } else {
        Write-Warning "[WARN] OpenSSL was not found on this system."
        Write-Warning "[WARN] Nginx requires PEM-formatted certificate (.crt) and private key (.key)."
        Write-Warning "[WARN] Please install Git for Windows or OpenSSL to automatically extract the private key."
        Write-Warning "[WARN] Temporary PFX containing the private key is saved at: $PfxPath"
    }

    Write-Output "[OK] SSL generation process completed successfully!"
    exit 0
}
catch {
    Write-Output "[ERROR] Failed to generate SSL certificates: $_"
    exit 1
}
