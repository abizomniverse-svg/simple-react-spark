# setup-hosts.ps1
# Add achme.com to Windows hosts file
# Must be run as Administrator

$ErrorActionPreference = "Stop"

$HostsFile = "C:\Windows\System32\drivers\etc\hosts"
$Entry = "127.0.0.1 achme.com"

Write-Output "[INFO] Configuring hosts file..."

$content = Get-Content $HostsFile -Raw

if ($content -match [regex]::Escape("achme.com")) {
    $content = $content -replace "(?m)^[^\r\n]*achme\.com[^\r\n]*\r?\n?", ""
    $content += "`r`n$Entry`r`n"
    Set-Content -Path $HostsFile -Value $content -Force
    Write-Output "[OK] Updated existing achme.com entry in hosts file"
} else {
    Add-Content -Path $HostsFile -Value "`r`n$Entry" -Force
    Write-Output "[OK] Added achme.com to hosts file"
}

Write-Output "[INFO] Hosts file entry: $Entry"
Write-Output "[INFO] Flushing DNS cache..."
ipconfig /flushdns | Out-Null
Write-Output "[OK] DNS cache flushed"
