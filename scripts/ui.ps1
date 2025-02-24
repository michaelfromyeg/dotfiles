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

# See more at https://winstall.app
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
  "Anysphere.Cursor"
  "Microsoft.PowerToys"
  "DominikReichl.KeePass"
  "JanDeDobbeleer.OhMyPosh"

  # Development
  "Git.Git"
  "GitHub.cli"
  "Microsoft.VisualStudioCode"
  "vim.vim"
  "CoreyButler.NVMforWindows"
  "Docker.DockerDesktop"
  "SQLite.SQLite"
  "QPDF.QPDF"
  "astral-sh.uv"
  "Anthropic.Claude"

  # Browsers and Communication
  "Mozilla.Firefox"
  "Google.Chrome"
  "SlackTechnologies.Slack"
  "Discord.Discord"
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
  "Notion.NotionCalendar"
  "Figma.Figma"
  "Beeper.Beeper"
  "ColdTurkeySoftware.ColdTurkeyBlocker"
  "Logitech.OptionsPlus"
  "TheDocumentFoundation.LibreOffice"
  "Notepad++.Notepad++"
  "KeePass.KeePass"
  "Microsoft.PowerToys"
  "flux.flux"

  # Cloud Storage
  "Dropbox.Dropbox"
  "Google.GoogleDrive"

  "PrivateInternetAccess.PrivateInternetAccess"
  "qBittorrent.qBittorrent"

  # Pocket Casts and ChatGPT are missing!
  # https://apps.microsoft.com/detail/9PCDBQX582BZ
)

foreach ($app in $apps) {
  Write-Host "Installing $app..." -ForegroundColor Green
  winget install --id $app --accept-source-agreements --accept-package-agreements -h
}

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Note: Some applications may require a system restart to complete installation." -ForegroundColor Yellow
