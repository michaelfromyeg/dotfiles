Write-Output "Pulling files into this repository..."
Copy-Item "$HOME/Documents/WindowsPowerShell/Microsoft.Powershell_profile.ps1" -Destination "./src"
Copy-Item "$env:LOCALAPPDATA/nvim/init.vim" -Destination "./src"
Write-Output "Done!"