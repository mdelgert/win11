#Requires -Version 5.1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================================="
Write-Host "Script: winget-configure-tools.ps1"
Write-Host "Description: Configure development tools."
Write-Host "Machine: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host "Time: $(Get-Date)"
Write-Host "OS Version: $([Environment]::OSVersion.Version)"
Write-Host "Working directory: $(Get-Location)"
Write-Host "=============================================================="
Write-Host ""

# winget configure -f C:\Source\win11\.config\vs2022.dsc.winget --accept-configuration-agreements
winget configure -f C:\Source\win11\.config\vs2026.dsc.winget --accept-configuration-agreements
# winget configure -f C:\source\win11\.config\sms22.dsc.winget --accept-configuration-agreements

Start-Sleep -Seconds 1