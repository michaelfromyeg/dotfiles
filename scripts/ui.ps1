#!/usr/bin/env pwsh

# Install a bunch of applications using Winget.

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "Please run as administrator"
  break
}

try {
  $wingetVersion = winget --version
} catch {
  Write-Error "Winget is not installed. Please install the App Installer from the Microsoft Store."
  exit 1
}

$apps = @(
  # Core Windows Utilities
  "Microsoft.PowerShell"
  "Microsoft.WindowsTerminal"
  "Microsoft.WSL"

  # Utilities
  "7zip.7zip"
  "AutoHotkey.AutoHotkey"
  "Calibre.Calibre"
  "WinDirStat.WinDirStat"
  "CursorID.CursorID"
  "Microsoft.PowerToys"

  # Development
  "Git.Git"
  "GitHub.cli"
  "Microsoft.VisualStudioCode"
  "vim.vim"
  "NodeJS.LTS"
  "Docker.DockerDesktop"
  "SQLite.SQLite"
  "QPDF.QPDF"

  # Browsers and Communication
  "Mozilla.Firefox"
  "Google.Chrome"
  "Slack.Slack"
  "Zoom.Zoom"
  "Mozilla.Thunderbird"

  # Media and File Management
  "DupeGuru.DupeGuru"
  "FlorianHeidenreich.Mp3tag"
  "VideoLAN.VLC"
  "GIMP.GIMP"
  "HandBrake.HandBrake"
  "OBSProject.OBSStudio"
  "Spotify.Spotify"
  "SumatraPDF.SumatraPDF"

  # Office and Productivity
  "Notion.Notion"
  "Figma.Figma"
  "Beeper.Beeper"
  "ColdTurkeySoftware.ColdTurkeyBlocker"
  "Logitech.OptionsPlus"
  "TheDocumentFoundation.LibreOffice"
  "Notepad++.Notepad++"
  "KeePass.KeePass"
  "Microsoft.PowerToys"

  # Cloud Storage
  "Dropbox.Dropbox"
  "Google.Drive"


  "PrivateInternetAccess.PrivateInternetAccess"
  "qBittorrent.qBittorrent"
)


foreach ($app in $apps) {
  Write-Host "Installing $app..." -ForegroundColor Green
  winget install --id $app --accept-source-agreements --accept-package-agreements -h
}

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Note: Some applications may require a system restart to complete installation." -ForegroundColor Yellow
