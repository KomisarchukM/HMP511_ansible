#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables WinRM for remote management from the Ansible control node.
.DESCRIPTION
    Configures a WinRM HTTP listener, the required firewall rules and the
    authentication settings expected by the Ansible `windows` inventory
    group (NTLM transport over port 5985).
.NOTES
    Run as Administrator on the target Windows host:
        powershell -ExecutionPolicy Bypass -File .\Enable-WinRM.ps1
    Then test from the control node:
        ansible windows -m ansible.windows.win_ping
#>

# 1. Ensure the network profile is Private (WinRM quickconfig requires it)
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'Private' } |
    Set-NetConnectionProfile -NetworkCategory Private

# 2. Enable the WinRM basic listener and firewall rules
winrm quickconfig -quiet

# 3. Allow Basic authentication (required for the NTLM transport used by Ansible)
winrm set winrm/config/service/auth '@{Basic="true"}'

# 4. Allow unencrypted connections (acceptable only inside a private network)
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# 5. Increase memory and timeout limits so Ansible modules work reliably
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
winrm set winrm/config '@{MaxTimeoutms="180000"}'
winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="1500"}'

# 6. Make sure the WinRM service starts automatically and is running
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# 7. Open the firewall port for the current network profile (default 5985)
New-NetFirewallRule -DisplayName 'WinRM-HTTP' -Direction Inbound -Protocol TCP `
    -LocalPort 5985 -Action Allow -Profile Private -ErrorAction SilentlyContinue

Write-Host "WinRM is enabled. Test from the control node:" -ForegroundColor Green
Write-Host "  ansible windows -m ansible.windows.win_ping"
