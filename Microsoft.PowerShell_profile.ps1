function Get-GitStatus { & git status $args }
New-Alias -Name s -Value Get-GitStatus

function Set-GitCommit { & git commit -am $args }
New-Alias -Name c -Value Set-GitCommit

function Set-GitCommit { & git push -u origin $args }
New-Alias -Name p -Value Set-GitCommit

function Go-To-Github { Set-Location ~/Documents/GitHub }
New-Alias -Name mgh -Value Go-To-Github 

function Go-To-Bitbucket { Set-Location ~/Documents/Bitbucket } 
New-Alias -Name mbb -Value Go-To-Bitbucket
