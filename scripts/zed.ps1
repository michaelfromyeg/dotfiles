# Sets up Zed from source for Windows

# PREREQUISITE: Install Vulkan. https://developer.nvidia.com/vulkan-driver

Write-Host "[zed] Installing..." -ForegroundColor Green

# Check for dry run
if ($env:dry -eq "1" -or $env:dry -eq "2") {
  exit
}

# Create apps directory if it doesn't exist
$appsDir = Join-Path $env:USERPROFILE "apps"
if (-not (Test-Path $appsDir)) {
  New-Item -ItemType Directory -Path $appsDir -Force | Out-Null
  Write-Host "Created apps directory at $appsDir"
}

# Install prerequisites using winget (Windows package manager)
Write-Host "Installing prerequisites..."
winget install -e --id Microsoft.VisualStudio.2022.BuildTools --silent
winget install -e --id Git.Git --silent
winget install -e --id Rustlang.Rust --silent
winget install -e --id PostgreSQL.PostgreSQL --silent

# Clone the repository
Write-Host "Cloning Zed repository..."
$zedDir = Join-Path $appsDir "zed"
if (-not (Test-Path $zedDir)) {
  git clone https://github.com/zed-industries/zed $zedDir
}
else {
  Write-Host "Zed repository already exists at $zedDir"
}

# Navigate to Zed directory
Set-Location $zedDir -ErrorAction Stop

# Build and run Zed
Write-Host "Building and running Zed..."
cargo run --release
