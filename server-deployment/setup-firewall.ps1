# setup-firewall.ps1
# Open ports for LAN access
# Must be run as Administrator

$ErrorActionPreference = "Stop"

Write-Output "[INFO] Configuring Windows Firewall..."

$rules = @(
    @{ Name = "Achme HTTP"; Port = 80; Proto = "TCP" },
    @{ Name = "Achme HTTPS"; Port = 443; Proto = "TCP" },
    @{ Name = "Achme DNS UDP"; Port = 53; Proto = "UDP" },
    @{ Name = "Achme Backend API"; Port = 5000; Proto = "TCP" },
    @{ Name = "Achme Frontend Vite"; Port = 5173; Proto = "TCP" }
)

foreach ($rule in $rules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-NetFirewallRule -DisplayName $rule.Name
    }
    New-NetFirewallRule -DisplayName $rule.Name `
        -Direction Inbound `
        -Protocol $rule.Proto `
        -LocalPort $rule.Port `
        -Action Allow `
        -Profile Any `
        -Enabled True | Out-Null
    Write-Output "[OK] Firewall rule: $($rule.Name) ($($rule.Proto)/$($rule.Port))"
}

Write-Output "[OK] All firewall rules configured"
