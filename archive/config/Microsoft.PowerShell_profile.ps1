# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Git aliases
function Get-GitStatus { & git status $args }
New-Alias -Name s -Value Get-GitStatus
function Set-GitCommit { & git commit -am $args }
New-Alias -Name c -Value Set-GitCommit
function Set-GitPush { & git push -u origin $args }
New-Alias -Name p -Value Set-GitPush

# Powerline features
Import-Module posh-git
Import-Module oh-my-posh
Set-Theme Paradox
