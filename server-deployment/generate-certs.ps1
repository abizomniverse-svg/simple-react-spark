# generate-certs.ps1
# Generate self-signed SSL certificates for achme.com
# Must be run as Administrator

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SslDir = Join-Path $ProjectRoot "ssl"

$CaSubject = "CN=Achme Private Root CA, O=Achme Corporation, C=US"
$CertSubject = "CN=achme.com"

$ActiveLanIp = "127.0.0.1"
try {
    $ActiveLanIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi','Ethernet' -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
} catch {}
if (-not $ActiveLanIp) { $ActiveLanIp = "127.0.0.1" }

Write-Output "[INFO] Detected LAN IP: $ActiveLanIp"
Write-Output "[INFO] Generating SSL certificates..."

if (-not (Test-Path $SslDir)) {
    New-Item -ItemType Directory -Path $SslDir -Force | Out-Null
}

$StoreLocation = "LocalMachine"
$StorePath = "Cert:\$StoreLocation\My"

$CaCert = Get-ChildItem -Path $StorePath | Where-Object { $_.Subject -eq $CaSubject } | Select-Object -First 1

if (-not $CaCert) {
    Write-Output "[INFO] Creating Achme Private Root CA..."
    $CaCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
        -Subject $CaSubject -KeyExportPolicy Exportable `
        -HashAlgorithm sha256 -KeyLength 2048 `
        -CertStoreLocation $StorePath `
        -KeyUsage CertSign, CRLSign, DigitalSignature `
        -NotAfter (Get-Date).AddYears(10)
    Write-Output "[OK] Root CA created"
} else {
    Write-Output "[OK] Root CA already exists"
}

$RootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", $StoreLocation)
$RootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$IsInstalled = $false
foreach ($Cert in $RootStore.Certificates) {
    if ($Cert.Thumbprint -eq $CaCert.Thumbprint) { $IsInstalled = $true; break }
}
if (-not $IsInstalled) {
    $RootStore.Add($CaCert)
    Write-Output "[OK] Root CA installed in Trusted Root store"
} else {
    Write-Output "[OK] Root CA already in Trusted Root store"
}
$RootStore.Close()

$CaCertPath = Join-Path $SslDir "AchmeRootCA.crt"
$CaCertPem = "-----BEGIN CERTIFICATE-----`r`n" + [System.Convert]::ToBase64String($CaCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`r`n-----END CERTIFICATE-----"
$CaCertPem | Out-File -FilePath $CaCertPath -Encoding ascii -Force
Write-Output "[OK] Exported CA cert: $CaCertPath"

$DnsNames = @("achme.com", "*.achme.com", "localhost", "127.0.0.1", $ActiveLanIp)

$DomainCert = New-SelfSignedCertificate -Type SSLServerAuthentication `
    -Subject $CertSubject -DnsName $DnsNames `
    -Signer $CaCert -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation $StorePath `
    -NotAfter (Get-Date).AddYears(3)
Write-Output "[OK] Domain certificate created"

$CertPath = Join-Path $SslDir "achme.crt"
$CertPem = "-----BEGIN CERTIFICATE-----`r`n" + [System.Convert]::ToBase64String($DomainCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`r`n-----END CERTIFICATE-----"
$CertPem | Out-File -FilePath $CertPath -Encoding ascii -Force
Write-Output "[OK] Exported domain cert: $CertPath"

$PfxPassword = "AchmeSecurePass123!"
$PfxPath = Join-Path $SslDir "achme.pfx"
$SecurePassword = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
Export-PfxCertificate -Cert $DomainCert -FilePath $PfxPath -Password $SecurePassword -Force | Out-Null

$KeyPath = Join-Path $SslDir "achme.key"
$OpenSslPath = ""
$SearchPaths = @(
    "openssl.exe",
    "C:\Program Files\Git\usr\bin\openssl.exe",
    "C:\Program Files (x86)\Git\usr\bin\openssl.exe",
    "C:\Program Files\Git\bin\openssl.exe",
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Git\usr\bin\openssl.exe")
)
foreach ($Path in $SearchPaths) {
    if ($Path -eq "openssl.exe") {
        $Check = Get-Command "openssl.exe" -ErrorAction SilentlyContinue
        if ($Check) { $OpenSslPath = "openssl.exe"; break }
    } elseif (Test-Path $Path) { $OpenSslPath = $Path; break }
}

if ($OpenSslPath) {
    Write-Output "[INFO] Extracting private key with OpenSSL..."
    $Command = "& `"$OpenSslPath`" pkcs12 -in `"$PfxPath`" -nocerts -nodes -out `"$KeyPath`" -password pass:`"$PfxPassword`""
    Invoke-Expression $Command | Out-Null
    if (Test-Path $KeyPath) {
        Write-Output "[OK] Private key extracted: $KeyPath"
        Remove-Item -Path $PfxPath -Force
    } else {
        Write-Output "[WARN] OpenSSL extraction failed. Falling back to PowerShell export..."
    }
}

if (-not (Test-Path $KeyPath)) {
    Write-Output "[INFO] Using PowerShell to export private key (no OpenSSL needed)..."
    try {
        $certBytes = $DomainCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $PfxPassword)
        [System.IO.File]::WriteAllBytes($PfxPath, $certBytes)

        $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $pfx.Import($PfxPath, $PfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        $privateKey = $pfx.PrivateKey
        $keyBytes = $privateKey.ExportRSAPrivateKey()
        $keyPem = "-----BEGIN RSA PRIVATE KEY-----`r`n" + [System.Convert]::ToBase64String($keyBytes, [System.Base64FormattingOptions]::InsertLineBreaks) + "`r`n-----END RSA PRIVATE KEY-----"
        $keyPem | Out-File -FilePath $KeyPath -Encoding ascii -Force
        Write-Output "[OK] Private key exported via PowerShell: $KeyPath"
        Remove-Item -Path $PfxPath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Output "[WARN] Could not export private key: $_"
        Write-Output "[INFO] PFX saved at: $PfxPath - use OpenSSL to extract .key manually"
    }
}

Write-Output "[OK] SSL certificates generated successfully!"
Write-Output "[INFO] LAN IP $ActiveLanIp included in certificate"
