Write-Output "Pushing files from this repository to their respective desintations..."
Copy-Item "./src/Microsoft.PowerShell_profile.ps1" -Destination "$HOME/Documents/WindowsPowerShell"
Copy-Item  "./src/init.vim" -Destination "$env:LOCALAPPDATA/nvim"
Write-Output "Done!"