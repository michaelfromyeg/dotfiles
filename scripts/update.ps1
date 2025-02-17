#!/usr/bin/env pwsh

# Updates everything you can update, on a Windows computer.

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "Please run as administrator"
  break
}

Write-Host "[update] Running system updates..." -ForegroundColor Green

# Install Windows Update module if not present
if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "Installing Windows Update PowerShell module..." -ForegroundColor Yellow
    Install-Module PSWindowsUpdate -Force
}

# Import Windows Update module
Import-Module PSWindowsUpdate

# Install Windows Updates
Write-Host "Checking for Windows updates..." -ForegroundColor Green
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot:$false

# Update winget packages if winget is available
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Updating winget packages..." -ForegroundColor Green
    winget upgrade --all --include-unknown --accept-source-agreements
}

# Clean up Windows update files
Write-Host "Cleaning up Windows update files..." -ForegroundColor Green
Stop-Service -Name wuauserv
Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv

Write-Host "Update process complete!" -ForegroundColor Green
Write-Host "Note: Some updates may require a system restart to complete installation." -ForegroundColor Yellow
